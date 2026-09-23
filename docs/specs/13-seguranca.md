# 13 — Segurança

Checklist obrigatório. Nenhum item é opcional para ir ao ar.

## Transporte e segredos

- [x] HTTPS em todas as páginas (`force_ssl`, HSTS). *(production.rb: `force_ssl` + `assume_ssl`; HSTS 2 anos com includeSubDomains conferido em produção — 20/09)*
- [x] Segredos (PayPal, Twilio, SES, S3, Sentry, master key) somente em ENV / credentials; `.env` gitignored. *(`.env` no `.gitignore`; produção só no Railway; `.env.example` sem valores)*
- [x] Usuário IAM do SES restrito a `ses:SendEmail`/`ses:SendRawEmail` com o `From` fixo; usuário IAM do S3 restrito ao bucket. Nunca credenciais root. *(Fase 0, 16/09: `launch-os-ses` / `launch-os-s3` com políticas próprias — checklist 0.4)*
- [x] Nenhuma chamada a API externa fora de `app/services/providers/` (`grep -rn "Faraday\|Aws::SESV2\|api.twilio.com\|paypal.com" app | grep -v app/services/providers` retorna vazio). *(20/09: só um comentário em `order.rb`; o SDK do PayPal no navegador é `modules/checkout.js`)*
- [x] Assinatura da Twilio validada com `secure_compare` (sem comparação `==`). *(2.7, 18/09)*
- [x] `/letter_opener` montado apenas em `development` (gem no grupo `:development`). *(routes.rb `if Rails.env.development?`; `letter_opener_web` no grupo development)*
- [x] `PAYPAL_WEBHOOK_SKIP_VERIFY` e similares levantam exceção no boot se definidos em `production`. *(`config/initializers/paypal.rb`; `twilio.rb` falha no boot com `TWILIO_ENABLED=true` sem credenciais)*
- [x] Nunca logar payloads com telefone/email em texto plano em logs públicos; filtrar via
      `config.filter_parameters += [:phone, :email, :password, :payer_email]`. *(4.2: `filter_parameter_logging.rb` — `email` cobre `payer_email`, `passw` cobre `password`; + `phone`, `from`/`to`/`body` (Twilio) e `name`; Sentry com `send_default_pii = false`)*

## Pagamento

- [x] Preço sempre do `Product` no backend; parâmetro de valor do cliente é ignorado. *(`Checkout::PaypalController#create` copia `product.price_cents`; T04 em `spec/requests/checkout/paypal_spec.rb`)*
- [x] Assinatura de todo webhook (PayPal e Twilio) verificada antes de qualquer processamento. *(`Providers::Paypal::VerifyWebhookSignature` — 400 e evento `ignored`; `Providers::Twilio::Client#valid_signature?` — 403)*
- [x] Idempotência: índice único `(provider, external_id)` em `webhook_events`; `Orders::MarkPaid` no-op se já pago; `PayPal-Request-Id` no create/capture. *(schema `index_webhook_events_on_provider_and_external_id`; `Client#create_order(request_id: order.id)`)*
- [x] Nenhum dado de cartão trafega ou é armazenado; pagamento 100% no PayPal. *(só `paypal_order_id`/`paypal_capture_id`/`payer_email` no `Order`)*
- [x] Transições de estado do `Order` apenas via services, dentro de `with_lock`. *(`Orders::MarkPaid/MarkRefunded/MarkDisputed/MarkFailed`, todos com `with_lock`)*

## Entrega

- [x] Bucket privado; PDF servido só por URL assinada (≤ 5 min); acesso direto ao objeto → 403. *(`storage.yml public: false`; `DownloadsController::SIGNED_URL_TTL = 5.minutes`; 20/09: `GET` no bucket e num objeto sem assinatura → 403 em produção)*
- [x] Token longo e aleatório (`has_secure_token`, ≥ 32 bytes); comparação por lookup indexado. *(`DownloadToken has_secure_token :token, length: 36`; `find_by(token:)` com índice único)*
- [x] Token verifica `order.paid?` a cada uso (refund/disputa revogam). *(`DownloadToken#active?` → `inactive_reason :not_paid`; `MarkRefunded`/`MarkDisputed` revogam)*
- [x] Expiração e limite de downloads aplicados. *(`DOWNLOAD_TOKEN_TTL_DAYS` / `DOWNLOAD_MAX_COUNT`; 410 em `DownloadsController`)*
- [x] Recuperação de acesso com resposta uniforme (não enumera emails) + rate limit + honeypot. *(2.5, 18/09)*

## Admin

- [x] `has_secure_password` (bcrypt), senha ≥ 12 chars, lockout após 5 falhas, rate limit no login. *(`User`: `PASSWORD_MIN_LENGTH = 12`, `MAX_FAILED_ATTEMPTS = 5`, `LOCK_DURATION = 15.minutes`; `Admin::SessionsController` 10/3 min por IP)*
- [x] Todas as rotas `/admin/*` atrás de `require_authentication`. *(`Authentication` incluído em `ApplicationController` — público é opt-out explícito; `/admin/sidekiq` com constraint de sessão nas rotas)*
- [x] CSRF habilitado em todos os controllers com sessão (`protect_from_forgery`); webhooks em `ActionController::API`. *(`Webhooks::PaypalController` e `TwilioController < ActionController::API`; checkout e beacon usam `null_session`/`skip_forgery_protection` por serem páginas cacheadas, sem sessão)*
- [x] Strong parameters em todos os formulários; nada de `permit!`. *(`grep -rn "permit!" app` vazio — 20/09)*
- [x] Dados de `Client` (email, telefone) visíveis só a `User` autenticado; telefone mascarado nas listagens. *(`Admin::ClientsController`; `AdminHelper#masked_phone`)*
- [x] Uploads validados (content type via magic bytes do Active Storage, tamanho, quantidade). *(`Product#pdf_file_format` — `application/pdf`, ≤ 50 MB; `#image_formats` — tipos e `PREVIEW_IMAGES_MAX`)*

## Aplicação

- [x] `Content-Security-Policy` configurada: `default-src 'self'`; `script-src` com `'self'`, `www.paypal.com`,
      `connect.facebook.net`, `www.googletagmanager.com`; `connect-src` com PayPal/Meta/GA; `img-src` com bucket,
      `www.facebook.com`; `frame-src` `www.paypal.com`. Nonces para scripts inline (`content_security_policy_nonce_generator`).
      *(4.2, 20/09: `config/initializers/content_security_policy.rb`. Nonce aleatório por requisição em `script-src` **e**
      `style-src`, sem `unsafe-inline` em lugar nenhum: os `<script>` do importmap saem com nonce, o Trix lê `<meta name="csp-nonce">`
      e o SDK do PayPal recebe `data-csp-nonce`. Também `object-src 'none'`, `frame-ancestors 'none'`, `base-uri` e `form-action 'self'`;
      `report-uri` no Sentry quando há `SENTRY_DSN`. Verificado em Chromium: LP com botões do PayPal, Pixel e GA4, e admin com Trix — zero violações.
      Sobre o cache da LP: o Thruster guarda header e corpo juntos, então cada cópia repete o nonce durante o `max-age` — sem risco porque
      nenhum conteúdo de usuário entra em script/style inline.)*
- [x] Headers: `X-Content-Type-Options`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` mínimo. *(nosniff e Referrer-Policy são padrão do Rails; `Permissions-Policy` via `default_headers` em `permissions_policy.rb` — o DSL do Rails 8.1 ainda emite só `Feature-Policy`)*
- [x] Rate limiting nativo (`rate_limit`) nos endpoints listados em [12-rotas.md](12-rotas.md). *(checkout 20/min, download 30/10 min, recuperação 5/10 min + 3/h por email, login 10/3 min, beacon 60/min)*
- [x] `config.hosts` com `www.devbatista.online`, `devbatista.online` e `*.up.railway.app` em produção. *(production.rb; `/up` excluído para o healthcheck do Railway)*
- [x] Sem `raise` silencioso em jobs: erros vão ao Sentry; retentativas limitadas. *(`retry_on` 3× nos jobs de mensagem; `sentry-sidekiq` com `report_after_job_retries = true` — reporta quando as tentativas acabam; dead jobs em `/admin/sidekiq`)*
- [x] `brakeman` sem alertas de confiança alta; `bundle audit` limpo; Dependabot habilitado. *(os três no CI — `scan_ruby`, `scan_js`; `.github/dependabot.yml` bundler + actions semanal; 20/09: 0 warnings, 0 vulnerabilidades)*
- [x] Logs de webhook, downloads, mensagens e falhas de login retidos ≥ 90 dias (Postgres) — payloads
      de webhook PODEM ser expurgados após 90 dias por recurring task. *(`WebhookEvent`, `DownloadToken` contadores, `MessageLog`, `User.failed_attempts`; nenhum expurgo automático ainda — decidir na Fase 6)*

## Dados pessoais

- [x] Telefone armazenado apenas com opt-in; texto e data/hora do consentimento gravados (TCPA). *(`clients.whatsapp_opt_in_at` + `whatsapp_opt_in_text`; T-checkout ignora o telefone sem opt-in)*
- [x] STOP respeitado imediatamente. *(`Webhooks::TwilioController#inbound` → `Client#opt_out_whatsapp!`; `Delivery.whatsapp?` checa `whatsapp_deliverable?` antes de cada envio)*
- [x] `PageVisit` guarda hash do IP, não o IP; `Order` guarda IP (necessário para CAPI e antifraude) — mencionado na Privacy Policy. *(`PageVisit.ip_hash` com sal diário; `orders.ip_address`)*
- [x] Privacy Policy, Terms e Refund Policy publicados e coerentes com a operação real (ver [14](14-paginas-legais.md)). *(21/09: as três com a razão social DevBatista Desenvolvimento de Software e Serviços LTDA, prazo de reembolso igual ao `refund_days` do produto e entrega descrita como é — só por email nesta versão)*
- [x] Backup do banco criptografado em repouso (recurso da plataforma). *(4.2: `pg_dump` diário para o bucket `launch-os-prod` — SSE-S3 e versionamento ativos desde a Fase 0; ver `Backups::DatabaseDump`)*

## Critérios de aceite

- [x] Checklist acima 100% marcado e revisado por segunda pessoa antes da campanha. *(23/09: os 39 itens anteriores marcados com evidência; revisão feita pelo Rafael, que não escreveu o código)*
- [x] Teste manual: adulterar valor no `POST /checkout/paypal` via DevTools → PayPal ainda cobra US$ 14.90. *(23/09, dev: POST com `amount_cents=1`, `price=0.01`, `value=0.01`, `currency=XXX` e um `purchase_units` forjado → `Order` criado com 1490 USD e o pedido no PayPal Sandbox com **14.90 USD**. O endpoint sequer lê preço: monta o pedido com `product.price_cents`. Pedido de teste removido do dev)*
- [x] Teste manual: `curl -X POST /webhooks/paypal` com corpo forjado → 400, nada processado. *(20/09 em produção: 400)*
- [x] Teste manual: URL do bucket sem assinatura → 403. *(20/09 em produção: bucket e objeto → 403)*
