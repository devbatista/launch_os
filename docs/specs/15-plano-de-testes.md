# 15 — Plano de testes

Framework: **RSpec** (`rspec-rails`) com **FactoryBot** + **Faker**, **shoulda-matchers** para validações,
**WebMock** (nenhuma chamada HTTP real), **SimpleCov** para cobertura. **System specs** (Capybara +
Selenium remoto) apenas para o fluxo da LP e do admin; o restante em model, service, job, request e mailer specs.

Sem fixtures: todo dado de teste vem de factories.

## Estrutura

```
spec/
  rails_helper.rb          # FactoryBot syntax, shoulda-matchers, WebMock.disable_net_connect!(allow: /selenium|web/), ActiveJob::TestHelper
  spec_helper.rb
  factories/
    users.rb  clients.rb  products.rb  benefits.rb  testimonials.rb  faqs.rb
    orders.rb  download_tokens.rb  webhook_events.rb  message_logs.rb  page_visits.rb
  support/
    paypal_stubs.rb        # WebMock: stub_paypal_oauth, stub_paypal_create_order, stub_paypal_capture(status:), stub_paypal_verify(valid:), paypal_webhook_payload(type:, order:)
    twilio_stubs.rb        # WebMock em api.twilio.com: stub_twilio_send(sid:), stub_twilio_send_error(code:, status:), twilio_signature_for(url, params) (HMAC-SHA1 real)
    ses_stubs.rb           # Aws::SESV2::Client.new(stub_responses: { send_email: { message_id: "..." } }) injetado em Providers::Ses::Client
    auth_helpers.rb        # sign_in_admin(user) para request/system specs
    attribution_helpers.rb # set_attribution_cookie(utm_source: ...)
    shared_contexts.rb     # "with a paid order", "with twilio enabled"
  models/
  services/
  jobs/
  requests/                # controllers são testados como request specs (padrão rspec-rails)
    admin/
    checkout/
    webhooks/
  mailers/
  system/
```

Factories principais (traits):

```ruby
factory :product do
  status { "published" }  # traits: :draft, :archived, :with_pdf, :with_images, :with_lp_content
end
factory :order do
  status { "pending" }    # traits: :paid (cria client + download_token), :failed, :refunded, :disputed, :with_attribution, :with_whatsapp_opt_in
end
factory :download_token do
  # traits: :expired, :revoked, :limit_reached
end
factory :client do
  # traits: :with_whatsapp_opt_in, :opted_out
end
```

Configurações em `rails_helper.rb`:
- `config.include FactoryBot::Syntax::Methods`, `config.include ActiveJob::TestHelper`.
- `Shoulda::Matchers.configure { |c| c.integrate { |w| w.test_framework :rspec; w.library :rails } }`.
- `WebMock.disable_net_connect!(allow_localhost: true, allow: [ENV["SELENIUM_URL"], "web"])`.
- `config.before(:each, type: :system) { driven_by :selenium, using: :headless_chrome, options: { url: ENV["SELENIUM_URL"] } }`.
- `ActiveJob::Base.queue_adapter = :test`; `ActionMailer::Base.delivery_method = :test`.
- `Sidekiq.strict_args!` também ativo em test (falha cedo em argumentos não serializáveis).

## Matriz de casos (do documento MVP → spec)

| # | Caso | Resultado esperado | Arquivo |
|---|---|---|---|
| T01 | Compra aprovada (capture COMPLETED) | Order paid, Client criado, token criado, `DeliverOrderJob` enfileirado 1×, email 1× | `spec/services/orders/mark_paid_spec.rb`, `spec/requests/checkout/paypal_spec.rb` |
| T02 | Webhook duplicado (mesmo `event.id`) | 1 `WebhookEvent`, nenhum pedido/email duplicado | `spec/requests/webhooks/paypal_spec.rb` |
| T03 | Webhook com assinatura inválida | 400, `signature_valid: false`, Order inalterado | idem |
| T04 | Preço adulterado no `POST /checkout/paypal` | Body enviado ao PayPal contém `product.price` (`expect(a_request(:post, ...).with { \|r\| ... })`) | `spec/requests/checkout/paypal_spec.rb` |
| T05 | Navegador fecha antes da Thank You (sem capture) | Webhook `PAYMENT.CAPTURE.COMPLETED` marca paid e envia email | `spec/jobs/process_paypal_webhook_job_spec.rb` |
| T06 | Token expirado / revogado / limite | `/download` → 410 / 410 / 429; mensagem e link de recuperação | `spec/requests/downloads_spec.rb` |
| T07 | Reembolso (`PAYMENT.CAPTURE.REFUNDED`) | Order refunded, token revogado, email de reembolso | `spec/services/orders/mark_refunded_spec.rb`, job spec |
| T08 | Compra com telefone + opt-in | `SendWhatsappMessageJob` enfileirado após email; `MessageLog` whatsapp `queued` → callback `delivered` | `spec/jobs/deliver_order_job_spec.rb`, `spec/requests/webhooks/twilio_spec.rb` |
| T09 | Compra sem opt-in ou sem telefone | Nenhum `MessageLog` whatsapp; email normal | `spec/jobs/deliver_order_job_spec.rb` |
| T10 | Twilio indisponível (500) / número inválido (63xxx) | Pedido e email intactos; log `failed`; retry só no 500 | `spec/jobs/send_whatsapp_message_job_spec.rb` |
| T11 | Callback Twilio com assinatura inválida | 403, `MessageLog` inalterado | `spec/requests/webhooks/twilio_spec.rb` |
| T12 | Segunda compra com o mesmo email | Reaproveita `Client`; `last_purchase_at` atualizado; nenhum duplicado | `spec/services/orders/mark_paid_spec.rb` |
| T13 | Login admin com senha errada 5× | `locked_at` preenchido; 6ª tentativa correta falha; após 15 min (`travel_to`) funciona | `spec/requests/admin/sessions_spec.rb` |
| T14 | Produto em rascunho | `/:slug` → 404; preview admin → 200 | `spec/requests/landing_pages_spec.rb`, `spec/requests/admin/products_spec.rb` |
| T15 | LP em mobile | Barra fixa (`sticky_cta`) e `#paypal-button-container` presentes (request spec); layout a 375 px conferido em navegador (Lighthouse mobile 100, screenshots) + checklist manual iOS/Android | `spec/requests/landing_pages_spec.rb` + [docs/qa](../qa/README.md) — *sem system spec no MVP (decisão 4.4: Selenium fica fora do compose/CI; conferências em navegador são feitas sob demanda)* |
| T16 | Capture chamado 2× | Segunda chamada idempotente, mesmo `thank_you_url` | `spec/requests/checkout/paypal_spec.rb` |
| T17 | Capture PENDING | Order pending; Thank You mostra "processing"; webhook posterior conclui | idem + job spec |
| T18 | Disputa criada / resolvida | `disputed` + token revogado; resolvida a favor → `paid` + token restaurado | `spec/services/orders/mark_disputed_spec.rb` |
| T19 | Recuperação de acesso | Email existente → novo token + email; inexistente → mesma resposta, 0 emails | `spec/requests/access_recoveries_spec.rb` |
| T20 | Inbound STOP | `whatsapp_opt_in: false`, `opt_out_at` preenchido; reenvio não dispara WhatsApp | `spec/requests/webhooks/twilio_spec.rb` |
| T21 | Purchase disparado uma vez | 1ª visita Thank You renderiza `fbq('track','Purchase')`; 2ª não | `spec/requests/thank_you_spec.rb` |
| T22 | Atribuição | Cookie de UTMs → campos do `Order` | `spec/requests/checkout/paypal_spec.rb` |
| T23 | Publicar produto sem PDF | Erro de validação; status permanece draft | `spec/models/product_spec.rb` |
| T24 | Slug reservado | Validação impede `admin`, `download`, etc. | `spec/models/product_spec.rb` |
| T25 | Transição inválida | `Orders::InvalidTransition` (ex.: `failed → paid`) | `spec/services/orders/*_spec.rb` |
| T26 | Rate limit | 11º login em 3 min → 429; 6ª recuperação em 10 min → 429 | request specs com `travel_to` e `Rails.cache.clear` |
| T27 | `TWILIO_ENABLED=false` | LP sem campo de telefone; job de WhatsApp retorna sem enviar | LP request spec + job spec (`ClimateControl` ou `stub_const`/`allow(ENV)`) |
| T28 | `Providers::Paypal::Client` | OAuth cacheado; 5xx/timeout → `TransientError`; 4xx → `PermanentError`; `ORDER_ALREADY_CAPTURED` tratado | `spec/services/providers/paypal/client_spec.rb` |
| T29 | `Providers::Twilio::Client` | POST form-encoded com Basic Auth e parâmetros corretos; 201 → sid; 63xxx → `PermanentError`; 5xx → `TransientError`; `valid_signature?` aceita assinatura correta e rejeita alterada | `spec/services/providers/twilio/client_spec.rb` |
| T30 | `Providers::Ses::Client` + `:ses_api` | `send_raw_email` envia o `mail.encoded` com `configuration_set_name`; retorna `message_id`; erros mapeados; delivery method grava `message_id` no `Mail` | `spec/services/providers/ses/client_spec.rb`, `spec/mailers/delivery_methods/ses_api_spec.rb` |

## Convenções de escrita

- Um `describe` por método/ação, `context` por cenário ("when the webhook signature is invalid").
- Preferir `let` enxuto e `subject { described_class.call(order, ...) }` nos services.
- Matchers: `change { Order.count }.by(1)`, `have_enqueued_job(DeliverOrderJob).with(order.id).once`,
  `have_http_status(:gone)`, `have_enqueued_mail(OrderMailer, :delivery)`.
- Request specs de webhooks fazem `post` com `params: raw_json, headers: { "CONTENT_TYPE" => "application/json", "PAYPAL-TRANSMISSION-ID" => ... }`.
- Jobs testados com `perform_now` (unidade) e enfileiramento verificado nos services (`have_enqueued_job`).
- Nada de `sleep`; tempo com `travel_to` / `freeze_time`.
- `rubocop-rspec` habilitado (limite de `let`s e de exemplos aninhados nos defaults).

## Model specs

`Product`, `Client`, `Order`, `DownloadToken`, `WebhookEvent`, `MessageLog`: validações e associações via
shoulda-matchers (`validate_presence_of`, `validate_uniqueness_of(:slug)`, `belong_to`, `have_one_attached`),
normalizações (`normalizes :email`), `active?`/`inactive_reason`, enums (`define_enum_for(:status)`).

## Mailer specs

`spec/mailers/order_mailer_spec.rb`: subject, destinatário, `reply_to`, presença do link `thank_you_url`
e da data de validade, versões HTML e texto. Previews em `spec/mailers/previews/order_mailer_preview.rb`
(visíveis em `/rails/mailers` em dev).

## System specs (opcionais no MVP, recomendados)

- `spec/system/landing_page_spec.rb`: LP renderiza blocos, FAQ abre, sticky CTA em viewport 375 px,
  campo de telefone com opt-in aparece só com Twilio habilitado. Botão PayPal real não é testado (SDK externo);
  verificar apenas que o container `#paypal-button-container` existe.
- `spec/system/admin_product_flow_spec.rb`: login → criar produto → adicionar benefit/FAQ via `nested_list.js`
  → upload → publish → LP pública responde.

Serviço `selenium/standalone-chromium` no compose (ver [02](02-docker-e-ambiente.md)).

## Cobertura

SimpleCov iniciado em `spec_helper.rb` com `minimum_coverage 90` para os grupos `Services`, `Jobs`,
`Webhooks` (`add_group` + `minimum_coverage_by_file` opcional). Relatório em `coverage/` (gitignored).

## Testes manuais (Sandbox e produção controlada)

Executar em ordem, registrar resultado em `docs/qa/` (data, ambiente, resultado):

1. Compra Sandbox completa em desktop e mobile (iOS Safari, Android Chrome).
2. Refund pelo painel Sandbox do PayPal → webhook → email.
3. Twilio Sandbox: compra com opt-in → mensagem recebida; responder STOP → opt-out.
4. Webhook real do PayPal via túnel (assinatura verificada de verdade).
5. Produção: 1 compra real de US$ 14.90 com cartão próprio → reembolso → verificar taxas cobradas.
6. Meta Test Events: `ViewContent`, `InitiateCheckout`, `Purchase` recebidos com valores corretos.
7. Email real via SES chega na caixa de entrada (Gmail, Outlook, iCloud) — não em spam; DKIM/SPF alinhados.
8. Lighthouse mobile na LP publicada.

## Critérios de aceite

- [x] Todos os casos T01–T30 automatizados e verdes em `bundle exec rspec`. *(4.4, 21/09: matriz conferida caso a caso — cada T tem spec com a tag no nome; T15 é request spec (barra fixa + container) + conferência em navegador; T28/T30 existiam sem tag, tagueados. 343 exemplos, 0 falhas)*
- [x] Cobertura de `app/services` (incluindo `providers/`), `app/jobs` e `app/controllers/webhooks` ≥ 90% (SimpleCov). *(21/09: Services 99%, Providers 99%, Jobs 97%, Webhooks 99%; `minimum_coverage 90` global no `spec_helper` — o CI falha se cair)*
- [x] WebMock em `disable_net_connect!` (exceto localhost/selenium/web); nenhuma request real vaza. *(rails_helper; SES via `stub_responses`)*
- [x] `rubocop-rspec` sem ofensas. *(no CI desde a Fase 1)*
- [ ] Testes manuais 1–8 registrados antes de ativar a campanha. *(registro em [docs/qa/README.md](../qa/README.md): 1-desktop, 2, 4, 6, 7, 8 ✅; faltam 1-mobile, 3 (Twilio Sandbox) e 5 (compra real, 4.5))*
