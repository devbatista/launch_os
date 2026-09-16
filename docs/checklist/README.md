# Checklist de desenvolvimento — MVP

Lista de execução, na ordem em que as coisas devem ser feitas. Cada bloco usa o **mesmo ID** do
[cronograma](../cronograma/README.md) e aponta para a [spec](../specs/README.md) que detalha o item.
Marque aqui os passos; ao fechar um bloco inteiro, atualize o status da tarefa no cronograma.

Regra de fechamento de bloco: código + teste verde + critério de aceite da spec conferido.

**Próximo passo:** → 1.1 (restante: RSpec/FactoryBot/WebMock, importmap entries + `data-module`, Sentry, `config.hosts`, CI com rspec, deploy no Railway) e, em paralelo, Fase 0 (contas e aprovações — DNS e SES primeiro).

---

## Fase 0 — Contas e aprovações (S0 · 14–20/09) · sem código

### 0.4 Domínio, hospedagem, banco, bucket, SES — spec [02](../specs/02-docker-e-ambiente.md), [09](../specs/09-notificacoes-email-whatsapp.md)
- [ ] Domínio `devbatista.online` com DNS na Cloudflare (nameservers apontados)
- [ ] Escolher hospedagem por container (Render / Fly.io / Railway / Kamal em VPS) e criar o projeto
- [ ] PostgreSQL 17 gerenciado com backup diário ativado
- [ ] Redis gerenciado (ou acessório no Kamal)
- [ ] Bucket privado S3-compatível (R2 ou S3) com versionamento; usuário IAM restrito ao bucket
- [ ] SES: criar identidade de domínio, Easy DKIM (3 CNAMEs, *DNS only*)
- [ ] SES: custom MAIL FROM `mail.devbatista.online` (MX + TXT SPF)
- [ ] DNS: `_dmarc` TXT (`p=quarantine`)
- [ ] SES: verificar identidade `support@devbatista.online`
- [ ] SES: usuário IAM só com `ses:SendEmail`/`ses:SendRawEmail`; access key → `SES_ACCESS_KEY_ID`/`SES_SECRET_ACCESS_KEY` (não gerar credenciais SMTP)
- [ ] SES: **solicitar saída do sandbox** (anotar data na seção 6 do cronograma)
- [ ] SES: configuration set `launch-os` com eventos Bounce/Complaint/Delivery
- [ ] Caixa `support@devbatista.online` funcionando (redirecionamento ok)

### 0.1 PayPal — spec [07](../specs/07-checkout-paypal.md)
- [ ] Conta PayPal Business criada e verificação de identidade enviada
- [ ] App no PayPal Developer (Sandbox): Client ID + Secret
- [ ] App no PayPal Developer (Live): Client ID + Secret
- [ ] Contas de comprador Sandbox criadas (US, com saldo)
- [ ] Credenciais guardadas fora do repositório (gerenciador de senhas)

### 0.2 Meta — spec [10](../specs/10-tracking-e-analytics.md)
- [ ] Meta Business criado; conta de anúncios com método de pagamento
- [ ] Pixel criado → `META_PIXEL_ID`
- [ ] Domínio `devbatista.online` verificado no Business Manager (meta tag ou DNS)
- [ ] Eventos priorizados (Aggregated Event Measurement) com Purchase no topo — pode ficar para a Fase 3

### 0.3 Twilio — spec [09](../specs/09-notificacoes-email-whatsapp.md)
- [ ] Conta Twilio; Account SID + Auth Token
- [ ] Sandbox for WhatsApp ativado; número de teste com `join <code>` enviado
- [ ] Solicitar WhatsApp Sender (número Twilio dedicado) vinculado ao Meta Business
- [ ] Submeter Content Template `order_delivery` (Utility) com as 4 variáveis → anotar SID `HX…`
- [ ] Anotar datas de solicitação na seção 6 do cronograma

### 0.5 Sentry, uptime, Git
- [ ] Projeto no Sentry → `SENTRY_DSN`
- [ ] Monitor de uptime gratuito apontando para `https://devbatista.online/up`
- [ ] Repositório Git criado (privado); `AGENTS.md`, `docs/` commitados
- [ ] Conta GA4 → `GA4_MEASUREMENT_ID` (pode ficar para a Fase 3)

**M0 — Contas prontas (20/09):** todos os itens acima marcados ou com data de solicitação registrada.

---

## Fase 1 — Base (S1–S2 · 21/09–04/10)

### 1.1 Projeto, Docker, RSpec, CI, deploy — spec [01](../specs/01-arquitetura-e-stack.md), [02](../specs/02-docker-e-ambiente.md)
- [x] `rails _8.1.3_ new launch_os --database=postgresql --css=tailwind --skip-jbuilder --skip-solid --skip-hotwire --skip-test`
- [ ] Gemfile conforme spec 01 — *parcial: sidekiq, redis, aws-sdk-s3, dotenv-rails, letter_opener_web já adicionados; faltam faraday, phonelib, aws-sdk-sesv2, sentry, rspec-rails, factory_bot_rails, faker, shoulda-matchers, webmock, simplecov, rubocop-rspec*
- [x] `config/initializers/generators.rb` com `primary_key_type: :uuid` — **antes de qualquer `rails g`**
- [ ] `ApplicationRecord` com `self.implicit_order_column = "created_at"`
- [x] `Dockerfile.dev` (libvips, libpq-dev) e `Dockerfile` de produção ajustado
- [x] `compose.yml`: db, redis, minio, minio-init, web, sidekiq (âncora `&rails`), css
- [x] `.env.example` completo; `.env` gitignored; `.dockerignore`
- [x] `config/storage.yml` com serviço `s3` (`public: false`); development e production usando `:s3`
- [x] `config/sidekiq.yml` (filas webhooks/mailers/whatsapp/default) e `initializers/sidekiq.rb` (`strict_args!`)
- [x] `queue_adapter = :sidekiq`; `cache_store = :redis_cache_store`
- [ ] `rails g rspec:install`; `rails_helper` com FactoryBot, shoulda, WebMock `disable_net_connect!`, ActiveJob `:test`
- [ ] `config/importmap.rb` com `pin_all_from "app/javascript"`; entries `application.js` e `landing.js`; loader por `data-module`
- [ ] `lib/http.js` (fetch JSON + CSRF) e `lib/cookies.js`
- [ ] Layouts: `application` (admin) e `landing` (público), Tailwind
- [ ] `app/services/providers/errors.rb` (`Providers::Error`, `TransientError`, `PermanentError`)
- [ ] `initializers/sentry.rb`; `config/environments/production.rb` (force_ssl, hosts, `delivery_method = :ses_api`, `assume_ssl`) — *parcial: force_ssl/assume_ssl vêm do gerador; faltam Sentry, `config.hosts` e `:ses_api`*
- [x] `development.rb`: `letter_opener_web`; rota `/letter_opener` só em dev
- [x] `bin/setup` funciona em container limpo (`db:prepare`, seeds)
- [ ] CI (GitHub Actions): rspec + rubocop + brakeman + bundler-audit
- [ ] Deploy inicial em produção (Railway: `web` + `worker` + plugins Postgres/Redis; `railway.json` já criado) com HTTPS respondendo `/up`
- [ ] ✅ Critérios de aceite das specs 01 e 02

### 1.2 Autenticação admin — spec [04](../specs/04-autenticacao-admin.md)
- [ ] `rails g authentication`; conferir `users`/`sessions` com `id: :uuid` e `user_id` uuid; mover rotas para `/admin/login`, `/admin/logout`
- [ ] Migration: `name`, `role`, `last_sign_in_at`, `failed_attempts`, `locked_at` em `users`
- [ ] `User#locked?`, `register_failed_attempt!` (bloqueia na 5ª por 15 min), reset ao logar
- [ ] Senha mínima de 12 caracteres
- [ ] `rate_limit to: 10, within: 3.minutes` em `Admin::SessionsController#create`
- [ ] `Admin::BaseController` com `require_authentication`; layout com sidebar
- [ ] Mensagem de erro genérica ("Invalid email or password") sem revelar existência
- [ ] Seed do admin via `ADMIN_EMAIL` / `ADMIN_PASSWORD`
- [ ] Specs: `spec/requests/admin/sessions_spec.rb` (T13, T26), `spec/models/user_spec.rb`
- [ ] ✅ Critérios de aceite da spec 04

### 1.3 Product, Benefit, Testimonial, Faq — spec [03](../specs/03-modelo-de-dados.md)
- [ ] Migration `products` (todas as colunas da spec, `price_cents`, `status` string, índices slug/status)
- [ ] Action Text instalado (`description`); Active Storage instalado — conferir `id: :uuid` e `record_id` uuid nas tabelas geradas
- [ ] Migrations `benefits`, `testimonials`, `faqs` com `position` e índice `(product_id, position)`
- [ ] `Product`: enum status, validações (slug formato/único, price > 0, compare_at > price, slugs reservados), `to_param = slug`
- [ ] `Product`: attachments (`pdf_file`, `cover_image`, `mockup_image`, `og_image`, `preview_images`) com variants WebP e validação de tipo/tamanho
- [ ] `Product#publishable?` (PDF, imagem, headline, price, ≥1 benefit) e validação ao publicar
- [ ] Factories com traits `:draft`, `:published`, `:archived`, `:with_pdf`, `:with_images`, `:with_lp_content`
- [ ] Seed de produto de exemplo em development
- [ ] Specs: `spec/models/product_spec.rb` (T23, T24), benefit/testimonial/faq
- [ ] ✅ Critérios de aceite da spec 03 (parte de Product)

### 1.4 CRUD admin de produtos — spec [05](../specs/05-catalogo-produtos-admin.md)
- [ ] Rotas `admin/products` + `publish`/`unpublish`/`archive`/`preview`
- [ ] `Admin::ProductsController` (index, new, create, show, edit, update, destroy só draft sem pedidos)
- [ ] Formulário com seções: básico, oferta (preço em dólares → cents), conteúdo (Trix), SEO
- [ ] Ações publish/unpublish/archive com validações e `published_at`
- [ ] Show com status, URL pública (copiar), resumo de pedidos
- [ ] Controllers aninhados `benefits`, `testimonials`, `faqs`: create/update/destroy/move respondendo partial HTML (fetch) ou redirect (sem JS)
- [ ] `modules/admin/nested_list.js` (submit interceptado → fetch → troca `innerHTML`)
- [ ] `modules/admin/confirm.js` (`data-confirm`)
- [ ] Specs: `spec/requests/admin/products_spec.rb`, `spec/requests/admin/benefits_spec.rb` (um por coleção)
- [ ] ✅ Critérios de aceite da spec 05 (exceto preview)

### 1.5 Uploads — spec [05](../specs/05-catalogo-produtos-admin.md)
- [ ] Campos de upload no formulário (PDF, capa, mockup, og_image, previews múltiplos com remoção individual)
- [ ] `modules/admin/file_preview.js`
- [ ] Upload funcionando no MinIO (dev) e no bucket real (produção)
- [ ] Variants pré-processados ao publicar (`preprocessed: true`)
- [ ] Spec: upload em request spec com `fixture_file_upload`; rejeição de tipo/tamanho inválidos
- [ ] Confirmar: objeto no bucket não acessível sem assinatura (403)

### 1.6 Landing page — spec [06](../specs/06-landing-page.md)
- [ ] Rota `GET /:slug` por último em `routes.rb`, com constraint
- [ ] `LandingPagesController#show` (`Product.published`, 404 caso contrário, `fresh_when`)
- [ ] Partials do template `direct_response`: hero, problem, benefits, whats_inside, previews, testimonials, offer, guarantee, faq, final_cta, footer
- [ ] Blocos opcionais somem quando vazios
- [ ] Bloco `#buy` com `data-module="checkout"` e `data-*` (botão PayPal entra na 2.1; por ora placeholder)
- [ ] Campo telefone + opt-in renderizado só com `TWILIO_ENABLED=true`
- [ ] Meta tags: title, description, og:*, canonical, robots
- [ ] `modules/sticky_cta.js` (barra mobile após o hero)
- [ ] Imagens com variants WebP, `loading="lazy"`, width/height
- [ ] Rodapé com suporte e links legais
- [ ] Lighthouse mobile ≥ 85 / acessibilidade ≥ 90
- [ ] Specs: `spec/requests/landing_pages_spec.rb` (T14); `spec/system/landing_page_spec.rb` (opcional)
- [ ] ✅ Critérios de aceite da spec 06

### 1.7 Preview de rascunho
- [ ] `Admin::ProductsController#preview` renderizando o mesmo template com `@preview = true`
- [ ] Banner "DRAFT PREVIEW", tracking desligado, botão de compra desabilitado
- [ ] Spec: preview 200 para draft/archived; público 404 (T14)

### 1.8 Páginas legais — spec [14](../specs/14-paginas-legais.md)
- [ ] `LegalPagesController` com `/privacy`, `/terms`, `/refund-policy`
- [ ] Textos em inglês cobrindo os itens mínimos da spec (dados coletados, PayPal/Twilio/SES/Meta/GA, cookies, CCPA/LGPD, reembolso com `refund_days`)
- [ ] `last_updated` visível; links no rodapé de todas as páginas públicas
- [ ] Spec: 200 nas três rotas; não capturadas por `/:slug`

### 1.9 Cadastrar e publicar o produto
- [ ] Produto *21-Day Procrastination Reset* cadastrado em produção com copy provisória, mockup e PDF placeholder
- [ ] Publicado; `https://devbatista.online/21-day-procrastination-reset` responde 200
- [ ] Facebook Sharing Debugger mostra og:image e description corretos

**M1 — LP em produção (04/10):** critérios de saída da Fase 1 no cronograma.

---

## Fase 2 — Pagamento e entrega (S3–S4 · 05/10–18/10)

### 2.1 Checkout PayPal (create/capture) — spec [07](../specs/07-checkout-paypal.md)
- [ ] `Providers::Paypal::Client` (Faraday): `access_token` com cache em Redis, `create_order`, `capture_order`, `get_order`, `verify_webhook_signature`; `PayPal-Request-Id`; timeouts; erros → `TransientError`/`PermanentError`
- [ ] `spec/support/paypal_stubs.rb`
- [ ] Migration `orders` (todas as colunas da spec, índices únicos em `paypal_order_id`/`paypal_capture_id`) + migration `clients`
- [ ] `Order` (enum status, `event_id` no `before_create`), `Client` (normalizes email, phonelib)
- [ ] Factories `orders` (traits por status, `:with_attribution`, `:with_whatsapp_opt_in`) e `clients`
- [ ] `Checkout::PaypalController#create`: produto publicado, phone E.164, `Order.create!` com preço do backend, `CreateOrder`, retorna `paypal_order_id`; `null_session`; rate limit
- [ ] `Checkout::PaypalController#capture`: idempotente, trata COMPLETED/PENDING/outros, `ORDER_ALREADY_CAPTURED`
- [ ] `modules/checkout.js`: IntersectionObserver → carrega SDK → `Buttons` com createOrder/onApprove/onError
- [ ] `modules/tracking.js` (wrappers no-op por enquanto)
- [ ] Compra Sandbox pelo navegador chega ao capture COMPLETED
- [ ] Specs: `spec/requests/checkout/paypal_spec.rb` (T01 parcial, T04, T16, T17, T22), `spec/services/providers/paypal/client_spec.rb`
- [ ] ✅ Critérios de aceite da spec 07 (parte de create/capture)

### 2.2 Webhook PayPal — spec [07](../specs/07-checkout-paypal.md)
- [ ] Migration `webhook_events` com índice único `(provider, external_id)`
- [ ] `Webhooks::PaypalController` (`ActionController::API`): verifica assinatura, `find_or_create_by!`, 400 se inválida, enfileira job, 200 rápido
- [ ] `ProcessPaypalWebhookJob` (fila `webhooks`): roteia por `event_type`, `retry_on`/`discard_on`, marca `processed`/`failed`
- [ ] `PAYPAL_WEBHOOK_SKIP_VERIFY` só em development (erro no boot se em production)
- [ ] Túnel HTTPS (cloudflared/ngrok) + webhook cadastrado no PayPal Developer com todos os eventos
- [ ] Webhook real do Sandbox recebido e gravado em `webhook_events`
- [ ] Specs: `spec/requests/webhooks/paypal_spec.rb` (T02, T03), `spec/jobs/process_paypal_webhook_job_spec.rb` (T05, T17)

### 2.3 Client e Order — services de transição — spec [07](../specs/07-checkout-paypal.md)
- [ ] `Orders::InvalidTransition`
- [ ] `Orders::MarkPaid` (with_lock, idempotente, find_or_create Client, opt-in, token, enfileira `DeliverOrderJob`)
- [ ] `Orders::MarkFailed`, `Orders::MarkRefunded` (revoga token, email), `Orders::MarkDisputed`, resolução de disputa
- [ ] Fallback: capture server-side se `CHECKOUT.ORDER.APPROVED` sem capture após 10 min (opcional)
- [ ] Specs: `spec/services/orders/mark_paid_spec.rb` (T01, T12), `mark_refunded_spec.rb` (T07), `mark_disputed_spec.rb` (T18), `mark_failed_spec.rb`, T25 em cada

### 2.4 DownloadToken, Thank You, download — spec [08](../specs/08-entrega-download-tokens.md)
- [ ] Migration `download_tokens`; modelo com `has_secure_token`, `active?`, `inactive_reason`, `revoke!`, `regenerate!`
- [ ] Factory com traits `:expired`, `:revoked`, `:limit_reached`
- [ ] `ThankYouController#show` (pending / ativo / inativo), `no-store`, marca `purchase_tracked_at` na 1ª visita
- [ ] `DownloadsController#show`: lock + incremento, redirect para URL assinada (5 min), 410/429, rate limit
- [ ] Download do PDF real funcionando em dev (MinIO) e produção
- [ ] Specs: `spec/requests/thank_you_spec.rb` (T21), `spec/requests/downloads_spec.rb` (T06), `spec/models/download_token_spec.rb`

### 2.5 Recuperação de acesso — spec [08](../specs/08-entrega-download-tokens.md)
- [ ] `AccessRecoveriesController` new/create; resposta idêntica exista ou não; honeypot; rate limit por IP e por hash de email
- [ ] `Delivery::ResendAccess` (regenera token se expirado/limite; não se revogado por refund/disputa)
- [ ] Spec: `spec/requests/access_recoveries_spec.rb` (T19, T26)

### 2.6 Jobs, email (SES), MessageLog — spec [09](../specs/09-notificacoes-email-whatsapp.md)
- [ ] Migration `message_logs`; modelo e factory
- [ ] `Providers::Ses::Client#send_raw_email` (`aws-sdk-sesv2`, `configuration_set_name`, erros mapeados) + `spec/support/ses_stubs.rb`
- [ ] `DeliveryMethods::SesApi` registrado como `:ses_api` (`initializers/action_mailer.rb`); ativo só em production
- [ ] `OrderMailer#delivery`, `#access_resend`, `#refund_confirmation` (HTML + texto, reply_to suporte)
- [ ] Previews em `spec/mailers/previews/`
- [ ] `DeliverOrderJob` → `SendAccessEmailJob` (+ WhatsApp na 2.7); `SendAccessEmailJob` com `MessageLog` e retry 3×
- [ ] `Delivery::DeliverOrder` e `Delivery::ResendAccess` ligados aos jobs
- [ ] Email chegando em `/letter_opener` após compra Sandbox
- [ ] Em produção: SES fora do sandbox; email de teste na caixa de entrada com DKIM/SPF alinhados
- [ ] Specs: `spec/mailers/order_mailer_spec.rb`, `spec/jobs/deliver_order_job_spec.rb` (T09), `spec/jobs/send_access_email_job_spec.rb`

### 2.7 WhatsApp via Twilio — spec [09](../specs/09-notificacoes-email-whatsapp.md)
- [ ] `initializers/twilio.rb`; `TWILIO_ENABLED` respeitado em toda a cadeia
- [ ] `Providers::Twilio::Client` (Faraday, `POST .../Messages.json`, Basic Auth, form-encoded; `valid_signature?` com HMAC-SHA1 + `secure_compare`) — conferir nomes dos parâmetros na doc oficial
- [ ] `Whatsapp::SendTemplateMessage` (monta variáveis e chama o provider)
- [ ] `SendWhatsappMessageJob` (fila `whatsapp`, `MessageLog`, retry só em erros transitórios, sem retry em 63xxx)
- [ ] `Webhooks::TwilioController#status` e `#inbound` com `RequestValidator`; STOP → opt-out; inbound encaminhado por email ao suporte (`SupportMailer`)
- [ ] Opt-in gravado no `Client` com texto e data/hora
- [ ] `spec/support/twilio_stubs.rb` (WebMock em `api.twilio.com`)
- [ ] Teste real no Sandbox da Twilio: mensagem recebida; callback `delivered` gravado; STOP funciona
- [ ] Specs: `spec/jobs/send_whatsapp_message_job_spec.rb` (T08, T10, T27), `spec/requests/webhooks/twilio_spec.rb` (T08, T11, T20)
- [ ] ✅ Critérios de aceite da spec 09

### 2.8 Admin de pedidos, clientes e webhook events — spec [11](../specs/11-admin-pedidos-clientes-dashboard.md)
- [ ] `Admin::OrdersController` index (filtros, busca, Pagy) e show (atribuição, token mascarado, mensagens, eventos)
- [ ] Ações: `resend` (email/whatsapp), `regenerate_token`, `revoke_token`, `resolve_dispute`
- [ ] `Admin::ClientsController` index/show, `revoke_whatsapp_opt_in`, telefone mascarado
- [ ] `Admin::WebhookEventsController` index/show (payload bruto)
- [ ] Sidekiq Web em `/admin/sidekiq` com constraint de sessão
- [ ] Specs: `spec/requests/admin/orders_spec.rb`, `spec/requests/admin/clients_spec.rb`, acesso sem sessão → redirect

**M2 — Compra Sandbox ponta a ponta (18/10):** critérios de saída da Fase 2 no cronograma.

---

## Fase 3 — Tracking, testes e go-live (S5 · 19–25/10)

### 3.1 Atribuição, Pixel, PageVisit — spec [10](../specs/10-tracking-e-analytics.md)
- [ ] `modules/attribution.js` (cookie `lo_attr` first-touch, 30 dias) + `lo_vid`
- [ ] `Tracking::AttributionCapture` lendo cookie/params/`_fbp`/`_fbc` no checkout → `Order`
- [ ] Migration `page_visits`; `RecordPageVisitJob` (ignora bots, `ip_hash`)
- [ ] Snippet do Pixel com nonce (só com `META_PIXEL_ID` e sem preview): PageView, ViewContent
- [ ] `InitiateCheckout` no `onClick` do botão; `Purchase` na Thank You com `eventID = order.event_id`, uma vez
- [ ] Banner de cookies simples (`lo_consent`)
- [ ] Meta Test Events: três eventos recebidos com value/currency
- [ ] Specs: T22 em `checkout/paypal_spec.rb`, T21 em `thank_you_spec.rb`, `spec/jobs/record_page_visit_job_spec.rb`

### 3.2 GA4, Sentry, monitoramento, hardening — spec [13](../specs/13-seguranca.md)
- [ ] GA4 (`view_item`, `begin_checkout`, `purchase` único)
- [ ] Sentry recebendo erro de teste; integração Sidekiq (dead jobs)
- [ ] Uptime monitor ativo; backup diário confirmado e **restauração testada**; versionamento do bucket
- [ ] CSP com nonces (PayPal, Meta, GA); headers de segurança; `config.hosts`; `filter_parameters`
- [ ] `brakeman` e `bundler-audit` limpos; Dependabot ativo
- [ ] Checklist da spec 13 percorrido item a item

### 3.3 Dashboard — spec [11](../specs/11-admin-pedidos-clientes-dashboard.md)
- [ ] `Admin::DashboardsController#show` com período e filtro por produto
- [ ] Cards: visitas, únicos, checkouts, vendas, faturamento bruto/líquido estimado, taxas, reembolsos, entregas
- [ ] Vendas por `utm_campaign`/`utm_content`; últimos pedidos; alertas (webhooks/mensagens falhas, disputas)
- [ ] Spec: `spec/requests/admin/dashboards_spec.rb` com uma compra refletida
- [ ] *(Pode ir para a Fase 5 se faltar tempo — registrar no cronograma)*

### 3.4 Plano de testes — spec [15](../specs/15-plano-de-testes.md)
- [ ] Matriz T01–T30 conferida: cada caso tem spec e está verde
- [ ] SimpleCov ≥ 90% em services/jobs/webhooks
- [ ] `rubocop` + `rubocop-rspec` sem ofensas
- [ ] Manuais 1–4 executados e registrados em `docs/qa/` (compra Sandbox desktop + mobile, refund Sandbox, Twilio Sandbox + STOP, webhook real via túnel)
- [ ] Falhas corrigidas

### 3.5 Go-live — spec [00](../specs/00-visao-geral.md), [13](../specs/13-seguranca.md)
- [ ] Credenciais PayPal Live em produção; webhook Live cadastrado
- [ ] `TWILIO_ENABLED` conforme aprovação do sender (true só com sender + template aprovados)
- [ ] Copy final da LP (C.4), PDF final (C.3) e políticas revisadas (C.5) publicados
- [ ] Manuais 5–8: compra real US$ 14.90 → entrega → reembolso; Events Manager; email real em Gmail/Outlook/iCloud; Lighthouse
- [ ] Definição de pronto (spec 00) 100% marcada
- [ ] Checklist de segurança (spec 13) 100% marcado e revisado por segunda pessoa

**M3 — Definição de pronto (25/10).**

---

## Trilha de conteúdo (paralela)

- [ ] C.5 Políticas em inglês revisadas — até 04/10
- [ ] C.1 PDF escrito (intro, semanas 1–3, anexos) — até 11/10
- [ ] C.2 Revisão do inglês — até 11/10
- [ ] C.4 Copy final da LP + mockup — até 11/10
- [ ] C.3 Diagramação do PDF + tracker imprimível — até 18/10
- [ ] C.6 Três criativos (dor / mecanismo / transformação), sem claims absolutos — até 25/10; subir como rascunho em 24/10

---

## Fase 4 — Campanha (S6 · 26/10–01/11)

- [ ] 4.1 Campanha criada manualmente (vendas, Purchase, Advantage+, EUA, inglês, 3 anúncios, R$ 18/dia)
- [ ] 4.1 Três anúncios aprovados pela Meta
- [ ] 4.2 Planilha diária preenchida (seção 8 do cronograma) — dias 1 a 7
- [ ] 4.3 Sentry, `MessageLog` e disputas verificados diariamente; suporte respondido em < 24 h
- [ ] 4.4 Análise final e cenário escolhido (seção 9 do cronograma) — 03/11

**M4 (26/10) e M5 (03/11).**

---

## Fase 5 — Pós-validação (sem datas)

Ver ordem sugerida no cronograma (seção 4.7). Não iniciar antes de M5.
