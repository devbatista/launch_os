# 08 — Entrega segura e download

O PDF nunca fica em URL pública permanente. Acesso apenas por token vinculado a um `Order` pago,
servido por URL assinada e temporária do bucket.

## DownloadToken

| Regra | Valor |
|---|---|
| Geração | `has_secure_token :token, length: 36` (urlsafe, ~48 chars) |
| Vinculado a | `Order` com `status = paid` (1:1) |
| Expiração | `DOWNLOAD_TOKEN_TTL_DAYS` (7) a partir da criação/regeneração |
| Limite | `max_downloads` (10); contador incrementado a cada download efetivo |
| Revogação | `revoked_at` — por refund, disputa ou ação do admin |
| Regeneração | cria novo `token`, zera `download_count`, nova `expires_at`, limpa `revoked_at` (somente se `order.paid?`) |

```ruby
def active?
  order.paid? && revoked_at.nil? && expires_at.future? && download_count < max_downloads
end

def inactive_reason   # :not_paid | :revoked | :expired | :limit_reached | nil
```

## Rotas e controllers

### `GET /thank-you/:token`

- Localiza `DownloadToken` pelo token (404 se inexistente).
- Se `order.pending?` (capture PENDING): exibe "Your payment is being processed. You'll get an email as soon as it clears." — sem botão de download.
- Se `active?`: página de sucesso com:
  - "Thank you, {name}!" + nome do produto + mockup.
  - Botão **Download Now** → `GET /download/:token`.
  - Aviso: "We also sent this link to {email}" (+ "and to your WhatsApp" se enviado).
  - Validade: "Link valid until {expires_at}" e limite de downloads.
  - Suporte e link para `/access/recover`.
  - Dispara `Purchase` no Pixel/GA4 **uma única vez** (ver spec 10) — usando `order.event_id`; marca `purchase_tracked_at`.
- Se inativo: mensagem específica por `inactive_reason` + link para recuperar acesso.
- `Cache-Control: no-store`.

### `GET /download/:token`

```
1. token = DownloadToken.find_by(token:) → 404 se nil
2. unless token.active? → render página de erro (410 Gone para expirado/revogado, 429 para limite) com CTA "Recover access"
3. token.with_lock { token.increment!(:download_count); token.touch(:last_downloaded_at) }
4. redirect_to token.order.product.pdf_file.url(expires_in: 5.minutes,
     disposition: "attachment", filename: "#{product.slug}.pdf"), allow_other_host: true
```

- URL assinada do S3/R2 com expiração de 5 minutos; o bucket é privado, então a URL só funciona nesse intervalo.
- Não fazer `send_data` do PDF pelo Rails (memória/latência); redirect para URL assinada.
- Rate limit: 30 req / 10 min por IP.
- Registrar log (`Rails.logger.info "download order=#{id} count=#{n}"`).

### `GET|POST /access/recover` — "Lost your download link?"

- Formulário com um único campo: email.
- POST:
  ```
  client = Client.find_by(email: params[:email].strip.downcase)
  if client
    client.orders.paid.find_each { |o| Delivery::ResendAccess.call(o, channels: [:email, (:whatsapp if client.whatsapp_deliverable?)]) }
  end
  redirect_to access_recover_path, notice: "If we find a purchase with that email, we'll send the link shortly."
  ```
- Resposta **idêntica** exista ou não o pedido (não expor quem comprou).
- `Delivery::ResendAccess` regenera o token se expirado/limite atingido (não se revogado por refund/disputa).
- Rate limit: 5 req / 10 min por IP e 3 req / hora por email (chave = hash do email).
- Honeypot field + tempo mínimo de preenchimento contra bots.

## `DeliverOrderJob` / `Delivery::DeliverOrder`

Executado após `Orders::MarkPaid`.

```
1. order = Order.paid.find(id); return unless order.download_token&.active?
2. SendAccessEmailJob.perform_later(order.id)                 # sempre
3. SendWhatsappMessageJob.perform_later(order.id, template: "order_delivery") if order.client.whatsapp_deliverable? && twilio_enabled?
```

Emails e WhatsApp são jobs separados e independentes: falha em um não afeta o outro
(requisito de resiliência). Detalhes de cada canal em [09-notificacoes-email-whatsapp.md](09-notificacoes-email-whatsapp.md).

## Ações do admin

- **Reenviar acesso** (email / WhatsApp): `Delivery::ResendAccess.call(order, channels:)`.
- **Regenerar token**: novo token, novo prazo.
- **Revogar token**: `revoke!`; download passa a retornar 410.
- Ver `download_count`, `last_downloaded_at`, `expires_at`.

## Critérios de aceite

- [ ] Após compra Sandbox, `/thank-you/:token` mostra o botão e `/download/:token` baixa o PDF real.
- [ ] URL assinada expira: copiar a URL do S3 e reutilizar após 5 min → erro do bucket.
- [ ] Acesso direto ao objeto no bucket (sem assinatura) → 403.
- [ ] Token de pedido `pending`/`failed` → download negado.
- [ ] 11º download → 429 com opção de recuperar; regenerar pelo admin volta a funcionar.
- [ ] Token expirado → 410; `/access/recover` com o email gera novo token e envia email.
- [ ] `/access/recover` com email inexistente → mesma mensagem, nenhum email.
- [ ] Refund → token revogado; `/download/:token` → 410 mesmo dentro do prazo.
- [ ] Purchase disparado só na primeira visita à Thank You (`purchase_tracked_at` preenchido).
