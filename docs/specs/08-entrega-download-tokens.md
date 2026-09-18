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

### `GET /thank-you/:id`

**Decisão (18/09):** a Thank You **não libera o download**. O link (por token) chega só por email e,
com opt-in, WhatsApp — a página é identificada pelo **id do pedido**, nunca pelo token, para que a URL
da página não dê acesso ao arquivo. Consequência: se o email não chegar, o caminho é `/access/recover`
ou o suporte.

- Localiza `Order` pelo id (404 se inexistente).
- Se `pending?` (capture PENDING): "Your payment is being processed. You'll get an email as soon as it clears."
- Se `paid?`: "Thank you, {name}!" + nome do produto + mockup + "We're sending your download link to {email}"
  (+ "and to your WhatsApp" se opt-in), validade do link, "Didn't get it? Resend my link" (`/access/recover`) e suporte.
  Dispara `Purchase` no Pixel/GA4 **uma única vez** (spec 10) usando `order.event_id`; marca `purchase_tracked_at`.
- Outros status: "This order is no longer active" + suporte.
- `Cache-Control: no-store`, `noindex`.

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
- Rate limit: 5 req / 10 min por IP e 3 req / hora por email (chave = SHA-256 do email normalizado). Ambos com
  `rate_limit` nativo (`name: "email"` para o segundo); estourou → 429 em texto puro.
- Honeypot (`website`, escondido) + tempo mínimo de preenchimento (2 s, timestamp assinado com
  `message_verifier(:access_recovery)`, validade 1 dia). Bot recebe a mesma resposta neutra, sem reenvio.
- Email com formato inválido volta ao form com erro (422) — não revela nada porque nem consulta o banco.
- Log: `[access] recovery ip=… found=… resent=…` — o email nunca vai para o log.

## `DeliverOrderJob` / `Delivery::DeliverOrder`

Executado após `Orders::MarkPaid`.

```
1. order = Order.paid.find(id); return unless order.download_token&.active?
2. SendOrderEmailJob.perform_later(order.id, template: "order_delivery")   # sempre
3. SendWhatsappMessageJob.perform_later(order.id, template: "order_delivery") if order.client.whatsapp_deliverable? && twilio_enabled?
```

`Delivery::ResendAccess.call(order, channels:)`: só pedido pago; cria o token se não existir, regenera se
expirado/limite, **não** reenvia se revogado; enfileira `SendOrderEmailJob(template: "access_resend")`.

Emails e WhatsApp são jobs separados e independentes: falha em um não afeta o outro
(requisito de resiliência). Detalhes de cada canal em [09-notificacoes-email-whatsapp.md](09-notificacoes-email-whatsapp.md).

## Ações do admin

- **Reenviar acesso** (email / WhatsApp): `Delivery::ResendAccess.call(order, channels:)`.
- **Regenerar token**: novo token, novo prazo.
- **Revogar token**: `revoke!`; download passa a retornar 410.
- Ver `download_count`, `last_downloaded_at`, `expires_at`.

## Critérios de aceite

- [x] Após compra Sandbox, `/thank-you/:id` confirma o pagamento e o link recebido por email (`/download/:token`) baixa o PDF real. *(18/09: email no `/letter_opener`, link → 303 para a URL assinada do MinIO; download em produção fica para M2)*
- [x] URL assinada expira: copiar a URL do S3 e reutilizar após 5 min → erro do bucket. *(dev/MinIO: 403 após expirar)*
- [x] Acesso direto ao objeto no bucket (sem assinatura) → 403.
- [x] Token de pedido `pending`/`failed` → download negado. *(402)*
- [x] 11º download → 429 com opção de recuperar; regenerar pelo admin volta a funcionar. *(regenerar via `regenerate!`; botão do admin na 2.8)*
- [x] Token expirado → 410; `/access/recover` com o email gera novo token e envia email. *(18/09: request spec + smoke em dev com `access_resend` no `/letter_opener`)*
- [x] `/access/recover` com email inexistente → mesma mensagem, nenhum email. *(18/09)*
- [x] Refund → token revogado; `/download/:token` → 410 mesmo dentro do prazo.
- [x] Purchase disparado só na primeira visita à Thank You (`purchase_tracked_at` preenchido). *(marcação e `data-event`; o Pixel é a 3.1)*
