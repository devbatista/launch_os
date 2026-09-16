# 01 — Arquitetura e stack

## Versões

| Componente | Versão | Observação |
|---|---|---|
| Ruby | 3.4.x (última patch) | imagem `ruby:3.4-slim` |
| Rails | **8.1.3** | fixar no Gemfile: `gem "rails", "8.1.3"` |
| PostgreSQL | 17 | imagem `postgres:17` |
| Redis | 7 | imagem `redis:7-alpine`; usado apenas pelo Sidekiq |
| Sidekiq | 8.x | `gem "sidekiq"`, adapter do Active Job |
| Node | não necessário | Propshaft + importmap + `tailwindcss-rails` (binário standalone) |

## Geração do projeto

```bash
rails _8.1.3_ new launch_os \
  --database=postgresql \
  --css=tailwind \
  --skip-jbuilder \
  --skip-solid \
  --skip-hotwire \
  --skip-test
```

Depois: `bin/rails generate rspec:install` (cria `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb`).

- `--skip-solid` remove Solid Queue/Cache/Cable; jobs vão para o **Sidekiq** e o cache usa
  `:redis_cache_store` (mesmo Redis). Action Cable não é usado no MVP.
- `--skip-hotwire` remove Turbo e Stimulus. O frontend é **ERB server-rendered com JavaScript puro**
  (módulos ES servidos via importmap, sem Node/bundler). Ver seção "Frontend" abaixo.
- Mantém os demais padrões do Rails 8: Propshaft, importmap, Dockerfile de produção, Thruster,
  Kamal (opcional; ver [02-docker-e-ambiente.md](02-docker-e-ambiente.md)).

Depois: `bin/rails generate authentication` (gerador nativo do Rails 8) como base do `User`/`Session`
— ver [04-autenticacao-admin.md](04-autenticacao-admin.md).

## Gems

```ruby
# Gemfile (além do padrão gerado)
gem "rails", "8.1.3"
gem "pg"
gem "puma"
gem "propshaft"
gem "importmap-rails"           # apenas para servir módulos ES próprios; sem turbo-rails / stimulus-rails
gem "tailwindcss-rails"
gem "sidekiq", "~> 8.0"
gem "redis", "~> 5.0"
gem "thruster"
gem "bcrypt"
gem "image_processing"          # variants (WebP) do Active Storage
gem "aws-sdk-s3", require: false    # S3 / R2 / MinIO (Active Storage)
gem "aws-sdk-sesv2", require: false # Providers::Ses::Client — envio de email pela API do SES
gem "faraday"                       # Providers::Paypal::Client e Providers::Twilio::Client (REST APIs)
gem "phonelib"                  # validação/normalização E.164
gem "sentry-ruby"
gem "sentry-rails"
gem "bootsnap", require: false

group :development, :test do
  gem "debug"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rspec", require: false
  gem "dotenv-rails"
  gem "bundler-audit", require: false
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  gem "web-console"
  gem "letter_opener_web"       # caixa de saída em /letter_opener (letter_opener puro não abre navegador em container)
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"                 # bloquear HTTP real (PayPal, Twilio) nos testes
  gem "shoulda-matchers"        # validações/associações em uma linha
  gem "simplecov", require: false
end
```

Decisão: **sem SDKs de provedor** (PayPal e Twilio via Faraday sobre as REST APIs oficiais); clientes finos são
menores, fáceis de testar com WebMock e não dependem de versão de SDK. Única exceção: `aws-sdk-sesv2`, pela
assinatura SigV4. Ver seção "Provedores externos".

## Estrutura de diretórios (além do padrão)

```
app/
  controllers/
    admin/                # namespace do painel (BaseController exige login)
    checkout/             # PaypalController (create / capture)
    webhooks/             # PaypalController, TwilioController
    landing_pages_controller.rb
    thank_you_controller.rb
    downloads_controller.rb
    access_recoveries_controller.rb
    legal_pages_controller.rb
  models/
    concerns/
  services/
    providers/            # ÚNICO lugar que fala com APIs externas (ver seção "Provedores externos")
      errors.rb           # Providers::Error, TransientError, PermanentError
      paypal/             # Client (Faraday, REST v2), CreateOrder, CaptureOrder, VerifyWebhookSignature
      ses/                # Client (aws-sdk-sesv2): send_raw_email
      twilio/             # Client (Faraday, REST API oficial): send_template_message, valid_signature?
    orders/               # MarkPaid, MarkRefunded, MarkDisputed, MarkFailed
    delivery/             # DeliverOrder, ResendAccess
    whatsapp/             # SendTemplateMessage (monta variáveis, usa Providers::Twilio::Client)
    tracking/             # AttributionCapture
  jobs/
    process_paypal_webhook_job.rb
    deliver_order_job.rb
    send_access_email_job.rb
    send_whatsapp_message_job.rb
    record_page_visit_job.rb
  mailers/
    order_mailer.rb
    support_mailer.rb
    delivery_methods/
      ses_api.rb          # delivery method do Action Mailer que delega a Providers::Ses::Client
  views/
    landing_pages/
      templates/
        direct_response/  # partials por bloco (hero, problem, benefits, ...)
    order_mailer/
    admin/
    legal_pages/
  javascript/
    application.js        # entry do admin (importa módulos abaixo conforme data-attributes da página)
    landing.js            # entry da LP (leve; só o necessário para checkout e tracking)
    lib/
      http.js             # fetch JSON com CSRF token e tratamento de erro
      cookies.js          # get/set de cookies first-party
    modules/
      attribution.js      # captura UTMs/fbclid → cookie
      checkout.js         # carrega PayPal SDK sob demanda, create/capture, redireciona
      tracking.js         # fbq / gtag wrappers (ViewContent, InitiateCheckout)
      sticky_cta.js       # barra fixa mobile após rolar o hero
      admin/
        nested_list.js    # adicionar/remover/reordenar benefits, testimonials, faqs via fetch
        confirm.js        # data-confirm em botões destrutivos
        file_preview.js   # preview de imagens antes do upload
config/
  initializers/
    paypal.rb, twilio.rb, sentry.rb, tracking.rb
docs/specs/
```

## Frontend (sem Hotwire)

Decisão: **ERB server-rendered + JavaScript puro em módulos ES**, servidos pelo importmap
(`config/importmap.rb` com `pin_all_from "app/javascript"`). Sem Turbo, Stimulus, Node, bundler ou
framework. Navegação é full-page (links e forms HTML normais). JS existe apenas onde o HTML não basta:
botão PayPal, tracking, listas aninhadas do admin.

Convenções:

- **Dois entrypoints**: `landing.js` (LP, Thank You, recuperação — mínimo possível) e `application.js`
  (admin). O layout de cada área inclui só o seu via `javascript_importmap_tags "landing"` / `"application"`.
- **Ativação por `data-module`**: cada módulo exporta `init(el)`; o entry faz
  `document.querySelectorAll("[data-module]")` e importa dinamicamente `modules/<nome>.js`.
  Exemplo: `<section id="buy" data-module="checkout" data-product-id="12" data-csrf="...">`.
- **Configuração via `data-*`** no HTML (ids, URLs, flags), nunca via JS inline com interpolação ERB —
  exceto os snippets de Pixel/GA4, que usam nonce da CSP.
- **Requisições**: `lib/http.js` envolve `fetch` com `Content-Type: application/json`,
  `X-CSRF-Token` (lido de `<meta name="csrf-token">`) e `X-Requested-With`; respostas de erro
  (`4xx/5xx`) viram exceção com o JSON do corpo.
- **Forms do admin**: submit HTML padrão (`method: :post` + `_method` para PATCH/DELETE via
  `button_to`/`form_with`). Sem `data-turbo-*`. Confirmação de ações destrutivas via `modules/admin/confirm.js`
  (`data-confirm="..."` → `window.confirm`).
- **Coleções aninhadas (benefits/testimonials/faqs)**: endpoints JSON no admin; `nested_list.js` faz
  `fetch` e substitui o `innerHTML` do container com o partial HTML devolvido pelo servidor
  (`render_to_string`). Simples, sem estado no cliente.
- **Sem jQuery, sem libs de UI**. `<details>` para FAQ, `<dialog>` para modais se necessário.
- **Progressive enhancement**: LP e admin funcionam sem JS exceto o botão PayPal (dependência
  inevitável do SDK) — nesse caso exibir `<noscript>` com instrução para habilitar JavaScript.
- **CSP**: scripts próprios via `<script type="module">` do importmap (`'self'`); inline apenas com nonce.
- **Sem `rails-ujs`**: `button_to` gera `<form>` real, o que já cobre PATCH/DELETE sem JS.

## Provedores externos (`app/services/providers/`)

Toda integração com API de terceiro — **PayPal, SES (email) e Twilio (WhatsApp)** — é um service em
`Providers::<Nome>::Client`, com integração **via API HTTP oficial** (nunca SMTP, nunca SDK de front-end para
lógica de servidor). Regra: **sem gems de SDK de provedor** (PayPal e Twilio via Faraday); a única exceção é o
`aws-sdk-sesv2`, porque a assinatura SigV4 da AWS não vale a pena reimplementar. Nenhum outro lugar da aplicação chama essas APIs diretamente: controllers, jobs e
mailers só conhecem o `Client`.

| Provider | Classe | Transporte | Por quê |
|---|---|---|---|
| PayPal | `Providers::Paypal::Client` | Faraday sobre REST API v2 | SDK oficial pouco mantido; API simples; fácil de stubar |
| Email | `Providers::Ses::Client` | `aws-sdk-sesv2` (`SendEmail` com conteúdo raw) | Única gem de provedor: assinatura SigV4 à mão não vale a pena; o SDK é só o cliente HTTP da API |
| WhatsApp | `Providers::Twilio::Client` | Faraday sobre a REST API oficial (`Messages.json`, Basic Auth) | API simples (um POST form-encoded); assinatura do webhook é HMAC-SHA1 de 3 linhas; sem gem |

Contrato comum:

```ruby
module Providers
  class Error < StandardError; end
  class TransientError < Error; end   # timeout, 5xx, rate limit → job faz retry
  class PermanentError < Error; end   # 4xx de validação, número inválido, credencial errada → sem retry
end

# Cada Client:
# - lê credenciais só de ENV/credentials no initialize (com defaults injetáveis para teste);
# - expõe métodos de domínio (create_order, send_raw_email, send_template_message…), não a API crua;
# - converte exceções do transporte em Providers::TransientError / PermanentError;
# - loga request/response sem dados sensíveis (filtrar email, telefone, tokens);
# - tem timeout explícito (open 5 s / read 10 s).
```

Jobs decidem retry pelo tipo de erro: `retry_on Providers::TransientError, attempts: 3`;
`discard_on Providers::PermanentError` (registrando no `MessageLog`/`WebhookEvent` e no Sentry).

Email continua sendo **renderizado** pelo Action Mailer (templates, multipart, previews, `have_enqueued_mail`),
mas **entregue** pela API: um delivery method customizado (`:ses_api`) recebe o objeto `Mail`, chama
`Providers::Ses::Client#send_raw_email(mail)` e grava o `MessageId` retornado pelo SES no `MessageLog`.
Detalhes em [09-notificacoes-email-whatsapp.md](09-notificacoes-email-whatsapp.md).

Regras:
- Controllers finos; regras de negócio em `app/services` (objetos com `.call`).
- Transições de estado do `Order` só via services em `Orders::*`, nunca `update(status:)` direto.
- Tudo que chama rede externa (PayPal, Twilio, email) roda em job, exceto create/capture do checkout
  (síncrono por natureza do fluxo do botão).

## Variáveis de ambiente

Segredos NUNCA no repositório. Em dev via `.env` (gitignored); em produção via variáveis do host
ou `config/credentials/production.yml.enc` + `RAILS_MASTER_KEY`.

| Variável | Uso |
|---|---|
| `RAILS_ENV`, `RAILS_MASTER_KEY`, `SECRET_KEY_BASE` | Rails |
| `DATABASE_URL` | PostgreSQL |
| `APP_HOST` (`devbatista.online`), `APP_PROTOCOL` (`https`) | `default_url_options`, links em emails |
| `SUPPORT_EMAIL` (`support@devbatista.online`) | rodapé, emails, template WhatsApp |
| `S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_FORCE_PATH_STYLE` | Active Storage (MinIO/R2/S3) |
| `SES_REGION` (`us-east-1`), `SES_ACCESS_KEY_ID`, `SES_SECRET_ACCESS_KEY`, `SES_CONFIGURATION_SET` (`launch-os`), `MAIL_FROM`, `MAIL_DOMAIN` (`devbatista.online`) | Email transacional via API do SES (só produção); usuário IAM separado do S3 |
| `PAYPAL_ENV` (`sandbox`/`live`), `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET`, `PAYPAL_WEBHOOK_ID` | PayPal |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_WHATSAPP_FROM` (`whatsapp:+1...`), `TWILIO_TEMPLATE_ORDER_DELIVERY_SID`, `TWILIO_ENABLED` | Twilio |
| `META_PIXEL_ID`, `GA4_MEASUREMENT_ID` | Tracking |
| `SENTRY_DSN` | Erros |
| `DOWNLOAD_TOKEN_TTL_DAYS` (7), `DOWNLOAD_MAX_COUNT` (10) | Entrega |
| `REDIS_URL` | Sidekiq e cache (`redis://redis:6379/0` em dev) |
| `SIDEKIQ_CONCURRENCY` | threads do worker (default 5) |

`TWILIO_ENABLED=false` DEVE permitir subir a aplicação sem WhatsApp (sender/template ainda em aprovação)
sem alterar código.

## Configurações Rails relevantes

```ruby
# config/environments/production.rb
config.force_ssl = true
config.assume_ssl = true
config.active_storage.service = :s3
config.active_job.queue_adapter = :sidekiq
config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"], namespace: "cache" }
config.action_mailer.delivery_method = :ses_api      # registrado em config/initializers/action_mailer.rb
config.action_mailer.raise_delivery_errors = true   # Providers::*Error sobe até o job → retry ou Sentry
config.action_mailer.default_url_options = { host: ENV["APP_HOST"], protocol: "https" }
config.time_zone = "UTC"

# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener_web
config.action_mailer.perform_deliveries = true
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
```

Email:
- Produção: **Amazon SES pela API** (`aws-sdk-sesv2`, operação `SendEmail` com conteúdo raw), encapsulada em
  `Providers::Ses::Client` e ligada ao Action Mailer pelo delivery method `:ses_api`. Usuário IAM restrito a
  `ses:SendEmail` + `ses:SendRawEmail`. Vantagem sobre SMTP: o `MessageId` do SES volta na resposta e é
  gravado no `MessageLog`, o que permite correlacionar bounces/complaints depois; erros vêm tipados.
- Dev: `letter_opener_web` monta `/letter_opener` (rota só em `development`); todo email enviado aparece lá.
- Test: `:test` (`ActionMailer::Base.deliveries`).
- Detalhes de setup do SES (domínio, DKIM, saída do sandbox) em [09-notificacoes-email-whatsapp.md](09-notificacoes-email-whatsapp.md).

Active Storage:
- Serviço `s3` com `public: false` (bucket privado). Downloads sempre por URL assinada com expiração curta
  (ver [08-entrega-download-tokens.md](08-entrega-download-tokens.md)).
- Imagens da LP servidas via `rails_representation` com variant WebP; PDF nunca via `rails_blob_path` público.

Sidekiq:

```yaml
# config/sidekiq.yml
:concurrency: <%= ENV.fetch("SIDEKIQ_CONCURRENCY", 5) %>
:queues:
  - [webhooks, 4]   # processamento de webhooks PayPal/Twilio — prioridade máxima
  - [mailers, 3]
  - [whatsapp, 2]
  - [default, 1]
```

- Adapter do Active Job (`perform_later`); os jobs continuam herdando de `ApplicationJob`
  (`retry_on` / `discard_on` do Active Job funcionam sobre o Sidekiq).
- `config/initializers/sidekiq.rb`: `Sidekiq.configure_server/client` com `REDIS_URL`; `Sidekiq.strict_args!`.
- Web UI em `/admin/sidekiq` montada dentro do namespace admin, protegida pela mesma autenticação
  (`authenticate` via constraint que verifica a `Session` do `User`) — ver [12-rotas.md](12-rotas.md).
- Dead set retido por 30 dias (padrão); jobs mortos geram alerta no Sentry (`sidekiq` integration do `sentry-ruby`).
- Tarefas periódicas (limpeza de `WebhookEvent` antigos, expiração de tokens) são opcionais no MVP;
  se necessárias, usar `sidekiq-cron` ou `sidekiq-scheduler`.
- Teste: adapter `:test` do Active Job + matchers do `rspec-rails` (`have_enqueued_job`, `have_been_enqueued`)
  e `perform_enqueued_jobs { ... }` (`ActiveJob::TestHelper` incluído em `rails_helper`). `Sidekiq::Testing` não é necessário.

## Ambientes

| Ambiente | Banco | Jobs | Storage | Email | PayPal | Twilio |
|---|---|---|---|---|---|---|
| development | Postgres (compose) | Sidekiq + Redis (compose) | MinIO (compose) | `letter_opener_web` (`/letter_opener`) | Sandbox | Sandbox |
| test | Postgres (compose) | adapter `:test` (sem Redis) | Disk (tmp) | `:test` | WebMock | WebMock |
| production | Postgres gerenciado | Sidekiq worker + Redis gerenciado | S3 / R2 | Amazon SES via API (`:ses_api`) | Live | Sender aprovado |

## Critérios de aceite

- [ ] `docker compose up` sobe web, sidekiq, db, redis e minio sem passos manuais além de `bin/setup`.
- [ ] `bundle exec rspec` passa em container limpo.
- [ ] Nenhum segredo commitado (`git grep` por `sk_`, `AKIA`, `AC[a-z0-9]{32}` retorna vazio).
- [ ] `brakeman` e `bundler-audit` sem alertas altos.
