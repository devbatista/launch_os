# 07 — Checkout PayPal

Integração com **PayPal Orders API v2** + **Webhooks**. Princípio inegociável: o acesso ao produto só é
liberado após confirmação **server-to-server** (webhook verificado ou capture com status `COMPLETED`
persistido pelo backend). O retorno do navegador à página de sucesso nunca é prova de pagamento.

## Pré-requisitos (fora do código)

- Conta PayPal Business verificada, apta a receber pagamentos internacionais.
- **Preferência de moeda da conta que recebe**: em *Preferências de pagamento → pagamentos em moeda diferente
  da minha* deixar "Sim, aceitar e converter" (ou manter saldo em USD). Com "Perguntar", todo capture volta
  `PENDING` com `RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION` e o comprador fica sem o produto até aceite manual
  (aconteceu no Sandbox em 17/09). Conferir na conta Live antes do go-live.
- App em PayPal Developer (Sandbox e Live) → `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET`.
- Webhook cadastrado apontando para `https://www.devbatista.online/webhooks/paypal` com os eventos:
  `CHECKOUT.ORDER.APPROVED`, `PAYMENT.CAPTURE.COMPLETED`, `PAYMENT.CAPTURE.DENIED`,
  `PAYMENT.CAPTURE.PENDING`, `PAYMENT.CAPTURE.REFUNDED`, `PAYMENT.CAPTURE.REVERSED`,
  `CUSTOMER.DISPUTE.CREATED`, `CUSTOMER.DISPUTE.RESOLVED` → `PAYPAL_WEBHOOK_ID`.
- Contas de comprador Sandbox para testes.

## Cliente da API — `Providers::Paypal::Client`

Único ponto que fala com a REST API do PayPal (contrato geral em [01 — Provedores externos](01-arquitetura-e-stack.md#provedores-externos-appservicesproviders)).

```ruby
module Providers
  module Paypal
    class Client
      BASE = { "sandbox" => "https://api-m.sandbox.paypal.com", "live" => "https://api-m.paypal.com" }

      def initialize(env: ENV.fetch("PAYPAL_ENV"), client_id: ENV.fetch("PAYPAL_CLIENT_ID"),
                     client_secret: ENV.fetch("PAYPAL_CLIENT_SECRET"), http: nil)
      def access_token          # POST /v1/oauth2/token (client_credentials); cache em Rails.cache (Redis) por expires_in - 60s
      def create_order(body, request_id:)    # POST /v2/checkout/orders
      def capture_order(id, request_id:)     # POST /v2/checkout/orders/:id/capture
      def get_order(id)                      # GET  /v2/checkout/orders/:id
      def verify_webhook_signature(headers:, body:)  # POST /v1/notifications/verify-webhook-signature → true/false
    end
  end
end
```

- Faraday com `request :json`, `response :json`, `open_timeout 5`, `timeout 10`; `Authorization: Bearer`.
- `PayPal-Request-Id` (idempotência da API): `order.id` em `create_order`, `"capture-#{order.id}"` em `capture_order`.
- Erros: `Faraday::TimeoutError`, `Faraday::ConnectionFailed`, respostas 5xx e 429 → `Providers::TransientError`;
  4xx (`INVALID_REQUEST`, `UNPROCESSABLE_ENTITY`, `AUTHENTICATION_FAILURE`) → `Providers::PermanentError`
  com o `name`/`details` do corpo. Exceção: `ORDER_ALREADY_CAPTURED` é tratado pelo `CaptureOrder` como sucesso.
- `Providers::Paypal::CreateOrder`, `CaptureOrder` e `VerifyWebhookSignature` são services finos que montam o
  payload a partir do `Order` e chamam o `Client`.

## Fluxo

### 1. `POST /checkout/paypal` — cria o pedido

Entrada (JSON enviado por `modules/checkout.js` via `fetch`): `product_id`, `phone` (opcional), `whatsapp_opt_in` (bool).
Controller com `skip_forgery_protection` (a LP é cacheável, o token CSRF pode estar desatualizado; o endpoint
não depende de sessão — segurança vem do preço server-side, rate limit e PayPal). **Não** usar `null_session`:
sem token válido ele troca o cookie jar por um vazio e a atribuição (`lo_attr`, `_fbp`, `_fbc`) se perde
(constatado em 17/09).

```
1. product = Product.published.find(product_id)           # 404 se não publicado
2. phone = Phonelib.parse(phone).e164 (nil se inválido/vazio; opt_in só vale com phone)
3. order = Order.create!(product:, amount_cents: product.price_cents, currency: product.currency,
                         phone:, whatsapp_opt_in:, **attribution_from_cookie, ip_address:, user_agent:)
4. resp = Providers::Paypal::CreateOrder.call(order)   →  body:
     intent: "CAPTURE",
     purchase_units: [{ reference_id: order.id, custom_id: order.id,   # UUID (36 chars; limite do PayPal é 127)
                        description: product.name (≤127 chars),
                        amount: { currency_code: "USD", value: "14.90" } }],
     payment_source: { paypal: { experience_context: { shipping_preference: "NO_SHIPPING",
                        user_action: "PAY_NOW", brand_name: "DevBatista",
                        return_url:, cancel_url: } } }
5. order.update!(paypal_order_id: resp["id"])
6. render json: { paypal_order_id: resp["id"] }
```

Rate limit: 20 req / minuto por IP. Valor **sempre** de `product.price_cents` — qualquer campo de preço
vindo do cliente é ignorado.

### 2. Aprovação pelo comprador (no PayPal)

O SDK JS chama `onApprove({ orderID })`.

### 3. `POST /checkout/paypal/capture` — captura

Entrada: `paypal_order_id`.

```
1. order = Order.find_by!(paypal_order_id:)
2. return já-pago (render token) se order.paid? && order.download_token   # idempotente
3. resp = Providers::Paypal::CaptureOrder.call(order)
4. capture = resp.dig("purchase_units",0,"payments","captures",0)
5. case capture["status"]
   when "COMPLETED" → Orders::MarkPaid.call(order, capture:, payer: resp["payer"], source: :capture)
   when "PENDING"   → order pendente, grava `pending_reason` (status_details.reason); render { status: "pending" } (Thank You mostra "processing, check your email")
   else             → Orders::MarkFailed.call(order); render 422
6. render json: { status:, thank_you_url: thank_you_url(order.download_token.token) }
```

Erro `ORDER_ALREADY_CAPTURED` do PayPal → tratar como sucesso: buscar `get_order` e seguir para `MarkPaid`.

### 4. `POST /webhooks/paypal` — confirmação server-to-server

```ruby
class Webhooks::PaypalController < ActionController::API   # sem CSRF, sem sessão
  def create
    raw = request.raw_post
    event = JSON.parse(raw)
    verified = Providers::Paypal::VerifyWebhookSignature.call(headers: request.headers, body: raw)

    we = WebhookEvent.create_with(event_type: event["event_type"], payload: event,
                                  headers: signature_headers, signature_valid: verified,
                                  status: verified ? "received" : "ignored")
                     .find_or_create_by!(provider: "paypal", external_id: event["id"])
    # unicidade (provider, external_id) garante idempotência; RecordNotUnique → 200 (já recebido)

    return head :bad_request unless verified   # 400, nada processado, log + Sentry

    ProcessPaypalWebhookJob.perform_later(we.id) if we.received?
    head :ok
  end
end
```

Responder 200 rapidamente; processamento no job (PayPal reenvia se não receber 2xx em ~30 s).

### 5. `ProcessPaypalWebhookJob`

| `event_type` | Ação |
|---|---|
| `PAYMENT.CAPTURE.COMPLETED` | localizar `Order` por `resource.custom_id` (ou `supplementary_data.related_ids.order_id`); `Orders::MarkPaid` (no-op se já paid) |
| `PAYMENT.CAPTURE.PENDING` | manter `pending`; registrar |
| `PAYMENT.CAPTURE.DENIED` | `Orders::MarkFailed` |
| `PAYMENT.CAPTURE.REFUNDED`, `PAYMENT.CAPTURE.REVERSED` | `Orders::MarkRefunded` |
| `CUSTOMER.DISPUTE.CREATED` | `Orders::MarkDisputed` (localizar por `disputed_transactions[].seller_transaction_id` = `paypal_capture_id`) |
| `CUSTOMER.DISPUTE.RESOLVED` | se `outcome` favorável ao vendedor → voltar a `paid` (restaurar token); se perdeu → `refunded` |
| `CHECKOUT.ORDER.APPROVED` | apenas registrar (o capture é feito pelo front) — PODE disparar capture server-side como fallback se após 10 min o pedido continuar `pending` |
| outros | `status: ignored` |

Ao final: `we.update!(status: "processed", processed_at:, order:)`; em exceção: `status: "failed", error:` + Sentry.
Job com `retry_on` (3 tentativas, backoff exponencial) para erros transitórios; `discard_on ActiveRecord::RecordNotFound`.

## Services de transição (`Orders::*`)

Toda transição roda em `order.with_lock` e é idempotente.

```ruby
class Orders::MarkPaid
  def call(order, capture:, payer:, source:)
    order.with_lock do
      return order if order.paid?                          # idempotência
      raise InvalidTransition unless order.pending? || order.disputed?

      client = Client.find_or_initialize_by(email: payer["email_address"].downcase)
      client.name  ||= [payer.dig("name","given_name"), payer.dig("name","surname")].compact.join(" ")
      client.country ||= payer.dig("address","country_code")
      if order.phone.present? && order.whatsapp_opt_in?
        client.assign_attributes(phone: order.phone, whatsapp_opt_in: true,
                                 whatsapp_opt_in_at: order.created_at,
                                 whatsapp_opt_in_text: I18n.t("checkout.whatsapp_opt_in"))
      end
      client.first_purchase_at ||= Time.current
      client.last_purchase_at = Time.current
      client.save!

      order.update!(status: :paid, paid_at: Time.current, client:,
                    paypal_capture_id: capture["id"], payer_email: client.email, payer_name: client.name)
      order.create_download_token!(expires_at: ENV.fetch("DOWNLOAD_TOKEN_TTL_DAYS", 7).to_i.days.from_now)
    end
    DeliverOrderJob.perform_later(order.id)      # fora do lock
    order
  end
end
```

`MarkRefunded`: `paid|disputed → refunded`, `refunded_at`, `download_token.revoke!`, enfileira email de reembolso.
`MarkDisputed`: `paid → disputed`, revoga token, marca flag para o admin.
`MarkFailed`: `pending → failed`.

Transições válidas:

```
pending  → paid | failed
paid     → refunded | disputed
disputed → paid | refunded
```

Qualquer outra levanta `Orders::InvalidTransition` (logada, não quebra o webhook — marca `failed` no `WebhookEvent`).

## Verificação de assinatura

`POST /v1/notifications/verify-webhook-signature` com:
`transmission_id`, `transmission_time`, `cert_url`, `auth_algo`, `transmission_sig` (headers `PAYPAL-*`),
`webhook_id` (ENV) e `webhook_event` (**corpo bruto parseado, sem reserialização**).
Resultado `verification_status == "SUCCESS"`. Em dev sem túnel, PODE-se usar `PAYPAL_WEBHOOK_SKIP_VERIFY=true`
**apenas em `development`** (código deve levantar erro se essa flag existir em production).

## Custos

Taxa PayPal internacional + spread cambial entram no cálculo de receita líquida no dashboard
(campo de configuração `PAYPAL_FEE_PERCENT` / `PAYPAL_FEE_FIXED_CENTS` — estimativa exibida, não valor real).

## Critérios de aceite

- [ ] Compra Sandbox completa: `Order.paid`, `paypal_capture_id` preenchido, `Client` criado, token gerado, `DeliverOrderJob` enfileirado uma única vez.
- [ ] Mesmo webhook enviado 2× → um único `WebhookEvent`, nenhum email duplicado.
- [ ] Webhook com assinatura inválida → 400, `signature_valid: false`, nada liberado.
- [ ] Body do `POST /checkout/paypal` com `amount` adulterado → PayPal recebe o preço do `Product`.
- [ ] Navegador fechado após aprovação (sem chamar capture): webhook `PAYMENT.CAPTURE.COMPLETED` (ou fallback de capture) processa e envia email.
- [ ] Refund no Sandbox → `refunded`, token revogado, email enviado.
- [ ] Capture chamado 2× para o mesmo pedido → segunda resposta retorna o mesmo `thank_you_url` sem efeitos colaterais.
- [ ] Todos os testes rodam com WebMock (nenhuma chamada real ao PayPal).
