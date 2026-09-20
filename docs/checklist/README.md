# Checklist de desenvolvimento — MVP

Lista de execução, na ordem em que as coisas devem ser feitas. Cada bloco usa o **mesmo ID** do
[cronograma](../cronograma/README.md) e aponta para a [spec](../specs/README.md) que detalha o item.
Marque aqui os passos; ao fechar um bloco inteiro, atualize o status da tarefa no cronograma.

Regra de fechamento de bloco: código + teste verde + critério de aceite da spec conferido.

**Próximo passo:** → 4.3 (dashboard). Da 4.2 (20/09) ficam dois passos de operação: erro de teste no Sentry após o deploy e o serviço cron de backup no Railway (+ restaurar um dump de produção). Em paralelo: M2 — download em produção ✅ (19/09); faltam webhook apontando para produção e o WhatsApp no Sandbox da Twilio (Content Template `HX…` + `join`). Fases 1–3 entregues; 4.1 ✅ em 19/09 (Pixel validado no Events Manager). Fase 2: 2.1–2.8 com código entregue em 17–18/09. Da 2.4 fica só confirmar o download em produção (M2). **M1 (LP em produção) atingido em 17/09**, antes da meta de 04/10. Fase 1 fechada; o polimento visual do admin virou a Fase 3 (3.1). Fase 0: 0.1 aguarda verificação PayPal; 0.3 Sender adiado até 04/10.

---

## Fase 0 — Contas e aprovações (S0 · 14–20/09) · sem código

### 0.4 Domínio, hospedagem, banco, bucket, SES — spec [02](../specs/02-docker-e-ambiente.md), [09](../specs/09-notificacoes-email-whatsapp.md)
- [x] Domínio `devbatista.online`: registrado na Namecheap, DNS na HostGator — **decisão: não migrar**; app em `www.devbatista.online`, apex redireciona
- [x] Hospedagem: **Railway** — projeto `launch_os` criado (conta `rafael@devbatista.com`), serviço `launch_os` conectado ao repo `devbatista/launch_os`, deploy automático no push em `main`
- [x] PostgreSQL gerenciado — plugin Postgres criado no Railway (● Online, volume `postgres-volume` 5 GB), `DATABASE_URL` do serviço `launch_os` aponta para `postgres.railway.internal:5432/railway`; versão em produção **18.6** (dev/spec usam `postgres:17` — sem impacto, mas anotar) (16/09)
- [x] Backup diário do volume `postgres-volume` — **decisão (16/09): não ativar por enquanto**; backups automáticos de volume exigem plano Pro no Railway. Seguir no Hobby durante o MVP; reavaliar (upgrade para Pro ou `pg_dump` agendado externo) antes do go-live — ver 3.2
- [x] Redis gerenciado — plugin Redis criado no Railway; `REDIS_URL` referenciado
- [x] Bucket **S3** `launch-os-prod` (`us-east-1`, acesso público bloqueado, versionamento ativo, SSE-S3); usuário IAM `launch-os-s3` com política `launch-os-s3-rw` (ListBucket + Get/Put/DeleteObject só nesse bucket); `S3_*` definidos no Railway (16/09)
- [x] SES: identidade de domínio `devbatista.online` criada em `us-east-1`, Easy DKIM (3 CNAMEs na HostGator) (16/09)
- [x] SES: custom MAIL FROM `ses.devbatista.online` — MX `10 feedback-smtp.us-east-1.amazonses.com` + TXT `v=spf1 include:amazonses.com ~all` conferidos via `dig`; MX do apex segue na HostGator (16/09)
- [x] DNS: `_dmarc` TXT `v=DMARC1; p=quarantine; rua=mailto:support@devbatista.online; adkim=r; aspf=r` — publicado em 16/09 após email de teste do SES chegar no Gmail com SPF/DKIM/DMARC = PASS (`smtp.mailfrom=…@ses.devbatista.online`, `dkim header.i=@devbatista.online`). Relatórios agregados chegam em `support@`
- [x] ~~SES: verificar identidade `support@devbatista.online`~~ — **desnecessário**: a identidade de domínio já cobre o envio; identidade de email só serviria para receber testes no sandbox, e a aprovação chega antes da 2.6
- [x] SES: usuário IAM `launch-os-ses` com política `launch-os-ses-send` (`ses:SendEmail`/`ses:SendRawEmail`); `SES_REGION`, `SES_CONFIGURATION_SET`, `SES_ACCESS_KEY_ID`, `SES_SECRET_ACCESS_KEY` definidos no Railway (16/09)
- [x] SES: **saída do sandbox** — solicitado e **aprovado em 16/09** (cota 50.000/dia, 14 emails/s); anotado na seção 6 do cronograma
- [x] SES: configuration set `launch-os` com destino SNS (`ses-launch-os`) para Bounce/Complaint/Delivery (16/09)
- [x] Caixa `support@devbatista.online` criada no cPanel e recebendo (teste 16/09). *Correção feita no caminho: `devbatista.com` estava como "Local" em Distribuição de e-mail apesar do MX no Google Workspace → trocado para "Servidor de mensagens remoto"; sem isso o Exim rejeitava remetentes `@devbatista.com` com "Sender verify failed"*

### 0.1 PayPal — spec [07](../specs/07-checkout-paypal.md)
- [x] Conta PayPal Business (CNPJ, separada da PF) criada e verificação de identidade enviada em 16/09 — prazo informado 2–4 dias úteis; Live no Developer fica "restricted" até aprovar (seção 6 do cronograma)
- [x] App no PayPal Developer (Sandbox): `launch_os` (Merchant) criado em 16/09 na conta CNPJ; Client ID + Secret no gerenciador de senhas
- [ ] App no PayPal Developer (Live): Client ID + Secret — *bloqueado pela verificação da conta; necessário só na 4.5*
- [x] Contas Sandbox: business (vendedor, `sb-…@business.example.com`) e personal US com saldo (comprador) — email/senha no gerenciador de senhas (16/09)
- [x] Credenciais Sandbox (Client ID + Secret) guardadas fora do repositório (gerenciador de senhas) (16/09)

### 0.2 Meta — spec [10](../specs/10-tracking-e-analytics.md)
- [x] Meta Business: portfólio `DevBatista` e conta de anúncios `DevBatista` (ID `2425512304918484`, BRL, São Paulo, CNPJ) já existiam; forma de pagamento adicionada em 16/09
- [x] Conjunto de dados (Pixel) `LaunchOS` criado → `META_PIXEL_ID=2908081392894300` no `.env` e no Railway (16/09)
- [x] Domínio `devbatista.online` verificado no portfólio DevBatista via TXT `facebook-domain-verification=…` no apex (16/09). *A 1ª tentativa deu "já verificado por outra empresa"; a 2ª passou — mensagem antiga fica na tela, ignorar*
- [ ] Eventos priorizados (Aggregated Event Measurement) com Purchase no topo — pode ficar para a Fase 4

### 0.3 Twilio — spec [09](../specs/09-notificacoes-email-whatsapp.md)
- [x] Twilio: **subconta `launch_os`** (SID `AC661274f8…`) criada dentro da conta existente para isolar credenciais, números e Sender do outro app; `TWILIO_ACCOUNT_SID`/`TWILIO_AUTH_TOKEN` no `.env` (16/09)
- [x] Sandbox for WhatsApp ativado na subconta (`join soil-brick` → `+1 415 523 8886`); template de teste entregue e resposta (inbound) recebida (16/09)
- [ ] Solicitar WhatsApp Sender (número Twilio dedicado) vinculado ao Meta Business — **adiado (decisão 16/09)**: exige upgrade da conta Twilio com saldo pré-pago mínimo de US$ 20; desenvolvimento segue no Sandbox. Plano B ativo: lançar com `TWILIO_ENABLED=false` (só email). Reavaliar até **04/10 (M1)** — depois disso a aprovação da Meta dificilmente chega antes do go-live
- [ ] Submeter Content Template `order_delivery` (Utility) com as 4 variáveis → anotar SID `HX…` — *depende do Sender; no Sandbox usar um template de teste criado no Content Template Builder (não precisa de aprovação)*
- [x] Datas anotadas na seção 6 do cronograma (16/09: Sandbox ativo; Sender adiado)

### 0.5 Sentry, uptime, Git
- [x] Sentry: org `devbatista`, projeto Rails `launch_os` (plano grátis, só Error Monitoring) → `SENTRY_DSN` no `.env` e no Railway (16/09). Gems + initializer entram na 1.1 (`send_default_pii = false`)
- [x] UptimeRobot (grátis): monitor HTTP `https://www.devbatista.online/up` a cada 5 min, alerta por email (16/09)
- [x] Repositório Git `devbatista/launch_os` (privado); `AGENTS.md`, `docs/` commitados; CI do Rails (lint/brakeman) e Dependabot ativos
- [ ] Conta GA4 → `GA4_MEASUREMENT_ID` (pode ficar para a Fase 4)

**M0 — Contas prontas (20/09):** todos os itens acima marcados ou com data de solicitação registrada.

---

## Fase 1 — Base (S1–S2 · 21/09–04/10)

### 1.1 Projeto, Docker, RSpec, CI, deploy — spec [01](../specs/01-arquitetura-e-stack.md), [02](../specs/02-docker-e-ambiente.md)
- [x] `rails _8.1.3_ new launch_os --database=postgresql --css=tailwind --skip-jbuilder --skip-solid --skip-hotwire --skip-test`
- [x] Gemfile conforme spec 01 (faraday, phonelib, aws-sdk-sesv2, bcrypt, sentry-ruby/rails/sidekiq, rspec-rails, factory_bot_rails, faker, rubocop-rspec, capybara, selenium-webdriver, webmock, shoulda-matchers, simplecov). `image_processing` 2.1 + `ruby-vips` explícito (PR #5 do Dependabot fechado por isso)
- [x] `config/initializers/generators.rb` com `primary_key_type: :uuid` — **antes de qualquer `rails g`**
- [x] `ApplicationRecord` com `self.implicit_order_column = "created_at"`
- [x] `Dockerfile.dev` (libvips, libpq-dev) e `Dockerfile` de produção ajustado
- [x] `compose.yml`: db, redis, minio, minio-init, web, sidekiq (âncora `&rails`), css
- [x] `.env.example` completo; `.env` gitignored; `.dockerignore`
- [x] `config/storage.yml` com serviço `s3` (`public: false`); development e production usando `:s3`
- [x] `config/sidekiq.yml` (filas webhooks/mailers/whatsapp/default) e `initializers/sidekiq.rb` (`strict_args!`)
- [x] `queue_adapter = :sidekiq`; `cache_store = :redis_cache_store`
- [x] `rails g rspec:install`; `rails_helper` com FactoryBot, shoulda, WebMock `disable_net_connect!`, ActiveJob::TestHelper, `Sidekiq.strict_args!`; SimpleCov em `spec_helper` com grupos Services/Jobs/Webhooks (mínimo sobe para 90 na Fase 2); `coverage/` gitignored
- [x] `config/importmap.rb` com `pin_all_from "app/javascript"`; entries `application.js` e `landing.js`; loader `lib/modules.js` (`activate()` importa `modules/<nome>` e chama `init(el)`; suporta vários módulos por elemento e `admin/<nome>`)
- [x] `lib/http.js` (fetch JSON + CSRF + `HttpError` com o corpo) e `lib/cookies.js` (get/set/remove, SameSite=Lax, Secure em https)
- [x] Layouts: `application` (admin, `lang=pt-BR`, `noindex`, entry `application`) e `landing` (público, `lang=en`, entry `landing`, `yield :head`/`:footer`), Tailwind — spec em `spec/views/layouts_spec.rb`
- [x] `Providers::Error`, `TransientError`, `PermanentError` — em `app/services/providers.rb` (não `providers/errors.rb`: o Zeitwerk exigiria a constante `Providers::Errors`; divergência da spec 01 anotada no arquivo)
- [x] `initializers/sentry.rb` (só production, `send_default_pii = false`, sem tracing); `production.rb` com force_ssl/assume_ssl, `ssl_options` e `host_authorization` liberando `/up`, `delivery_method = :ses_api` + `raise_delivery_errors` (o delivery method em si é registrado na 2.6)
- [x] `development.rb`: `letter_opener_web`; rota `/letter_opener` só em dev
- [x] `bin/setup` funciona em container limpo (`db:prepare`, seeds)
- [x] CI (GitHub Actions): job `test` (Postgres 17 + libvips + `bundle exec rspec`) somado a lint/brakeman/bundler-audit/importmap audit; `bin/ci` com step RSpec
- [x] Deploy inicial em produção: `https://launchos-production-9f6e.up.railway.app/up` → 200 (variáveis definidas via CLI; `S3_*` e `SES_*` reais desde 16/09)
- [x] Serviço `sidekiq` no Railway: mesmo repo (branch `main`), 27 variáveis copiadas do web (`DATABASE_URL`/`REDIS_URL` como referências aos plugins), *Custom Start Command* `bundle exec sidekiq -C config/sidekiq.yml` no dashboard, sem healthcheck. Logs confirmam Sidekiq 8.1.7 conectado ao Redis interno (17/09). Config as Code do Railway removido — ver decisão de 17/09 no cronograma
- [x] Domínio no Railway: `www.devbatista.online` adicionado; CNAME `www` → `0y02s4dz.up.railway.app` + TXT `railway-verify` na HostGator; certificado Let's Encrypt emitido; porta do domínio = 8080; `https://www.devbatista.online/up` → 200 (16/09)
- [x] Redirect 301 do apex `devbatista.online` → `https://www.devbatista.online` no cPanel (http e https OK)
- [ ] *(opcional)* marcar *Wild Card Redirect* no cPanel para `devbatista.online/caminho` preservar o caminho (hoje → 404)
- [x] `APP_HOST=www.devbatista.online` e `PORT=8080` fixados no Railway
- [x] `config.hosts` em production com `www.devbatista.online`, `devbatista.online`, `/.*\.up\.railway\.app\z/` (verificado com boot em `RAILS_ENV=production`)
- [ ] ✅ Critérios de aceite das specs 01 e 02 — *spec 01: os 4 conferidos (compose sobe, rspec verde em container, `git grep` de segredos vazio, brakeman/bundler-audit limpos). Spec 02: upload no MinIO conferido na 1.3 (seed + variant WebP); faltam email via job em `/letter_opener`, job processado pelo `sidekiq` e persistência do Redis (2.6)*

### 1.2 Autenticação admin — spec [04](../specs/04-autenticacao-admin.md)
- [x] `rails g authentication`; `users`/`sessions` com `id: :uuid` e `user_id` uuid; rotas em `/admin/login` (GET/POST) e `DELETE /admin/logout`; `PasswordsController`/`PasswordsMailer` e Action Cable removidos (reset só por console)
- [x] Migration `create_users` com `name`, `role` (default `admin`), `last_sign_in_at`, `failed_attempts` (0, not null), `locked_at`
- [x] `User#locked?`, `register_failed_attempt!` (bloqueia na 5ª por 15 min; bloqueio expirado zera a contagem), `register_successful_sign_in!`
- [x] Senha mínima de 12 caracteres (`User::PASSWORD_MIN_LENGTH`)
- [x] `rate_limit to: 10, within: 3.minutes` em `Admin::SessionsController#create` → 429; test env com `:memory_store` para o limite funcionar nos specs
- [x] `Admin::BaseController` com `require_authentication`; layout `application` renderiza sidebar (`admin/shared/_sidebar`) + flash quando autenticado; `Admin::DashboardsController#show` placeholder (cards na 3.3)
- [x] Mensagem genérica sem revelar existência — em português ("E-mail ou senha inválidos."), conforme regra de idioma do admin no AGENTS.md; a spec 04 cita o texto em inglês só como exemplo
- [x] Seed idempotente do admin via `ADMIN_EMAIL` / `ADMIN_PASSWORD` (+ `ADMIN_NAME` opcional)
- [x] Specs: `spec/requests/admin/sessions_spec.rb` (T13, T26, logout, return_to), `spec/requests/admin/dashboards_spec.rb`, `spec/models/user_spec.rb`, factory `users`
- [x] ✅ Critérios de aceite da spec 04 — todos cobertos por spec e conferidos no servidor de dev (login → dashboard com sidebar → logout → redirect)

### 1.3 Product, Benefit, Testimonial, Faq — spec [03](../specs/03-modelo-de-dados.md)
- [x] Migration `products` (todas as colunas da spec, `price_cents`/`compare_at_price_cents` integer, `status` string, índices `slug` único e `status`)
- [x] Action Text (`description`) e Active Storage instalados; 10 tabelas, todas `id: :uuid`, todas as `*_id` uuid, sem pgcrypto, sem float/decimal. Trix importado no entry `application.js`
- [x] Migrations `benefits`, `testimonials`, `faqs` com `position` e índice `(product_id, position)`; concern `Positioned` (posição sequencial por produto, `move(:up|:down)`)
- [x] `Product`: enum status, validações (slug formato/único/normalizado, gerado do nome, `RESERVED_SLUGS`, price > 0, compare_at > price), `to_param = slug`, `price`/`compare_at_price` em BigDecimal para o formulário
- [x] `Product`: attachments (`pdf_file`, `cover_image`, `mockup_image`, `og_image`, `preview_images`) com variants WebP `:lp`/`:thumb` (`preprocessed: true`) e validação de content type/tamanho/quantidade (PDF ≤ 50 MB; JPEG/PNG/WebP ≤ 5 MB; ≤ 8 previews) — variant conferido no MinIO
- [x] `Product#publishable?`/`missing_for_publish` (PDF, imagem, headline, price, ≥1 benefit), validação ao publicar, `publish`/`unpublish`/`archive`
- [x] Factories `product` (traits `:draft`, `:published`, `:archived`, `:with_pdf`, `:with_images`, `:with_lp_content`), `benefit`, `testimonial`, `faq`; fixtures `spec/fixtures/files` (PNG, PDF, TXT) + helper `AttachmentHelpers`
- [x] Seed de produto de exemplo em development (draft completo e publicável, com placeholders em `db/seeds/files`)
- [x] Specs: `spec/models/product_spec.rb` (T23, T24, anexos, publicação), `spec/models/positioned_spec.rb` (benefit/testimonial/faq)
- [x] ✅ Critérios de aceite da spec 03 (parte de Product): migrate em banco limpo, factories com traits, specs de slug/compare_at/PDF ao publicar, schema 100% uuid, sem float/decimal, `implicit_order_column`

### 1.4 CRUD admin de produtos — spec [05](../specs/05-catalogo-produtos-admin.md)
- [x] Rotas `admin/products` + `publish`/`unpublish`/`archive` (`:id` = slug); `preview` entra com a action na 1.7
- [x] `Admin::ProductsController` (index, new, create, show, edit, update, destroy só draft — checagem de pedidos entra na 2.1 com a tabela `orders`)
- [x] Formulário com seções: básico, oferta (preço em dólares → cents via `Product#price=`), conteúdo (Trix), SEO; arquivos entram na 1.5
- [x] Ações publish/unpublish/archive com validações e `published_at`; botão Publicar desabilitado com o que falta no `title`
- [x] Show com status, URL pública (botão copiar via `modules/admin/copy.js`), blocos/arquivos; resumo de pedidos é placeholder até a Fase 2
- [x] `Admin::CollectionItemsController` base + `benefits`/`testimonials`/`faqs`: create/update/destroy/move → partial `_list` (200/422) com `X-Requested-With`, redirect com flash sem JS; partial genérico `admin/products/_collection_list`
- [x] `modules/admin/nested_list.js` (submit interceptado → fetch form-encoded com token do `<meta>` → troca `innerHTML`; fallback para submit normal se a rede falhar)
- [x] `modules/admin/confirm.js` (`data-confirm` em forms/links, fase de captura) ativado no `<main>` do layout
- [x] Specs: `spec/requests/admin/products_spec.rb`; shared example "coleção do produto no admin" usado por `benefits_spec`, `testimonials_spec`, `faqs_spec`; helper `sign_in_admin`
- [x] ~~Polir o visual do admin~~ → **movido para a Fase 3 (3.1)**, decisão de 18/09: fazer de uma vez, com todas as telas reais do painel (produtos, pedidos, clientes, webhooks) já existentes
- [ ] ✅ Critérios de aceite da spec 05 (exceto preview) — *feito: criar draft via admin, publicar sem PDF mantém draft, publish preenche `published_at`, coleções via fetch e sem JS. Faltam: LP 200 em `/:slug` (1.6), preview (1.7), segundo produto (H5, após 1.9)*

### 1.5 Uploads — spec [05](../specs/05-catalogo-produtos-admin.md)
- [x] Campos de upload no formulário (PDF, capa, mockup, og_image, previews múltiplos com remoção individual) — *seção "Arquivos" em `_form` + partial `_attachment_field`; remoção via `Admin::AttachmentsController#destroy` (forms DELETE fora do form principal, ligados pelo atributo `form`; funciona sem JS). Previews são acrescentados no update (Rails ≥ 7.1 substituiria a coleção); campos vazios são descartados (`""` apagaria o anexo). Arquivo obrigatório de produto publicado não pode ser removido sem despublicar. Imagens atuais servidas pelo proxy do Active Storage (sem mexer no /etc/hosts)*
- [x] `modules/admin/file_preview.js` — *nome, tamanho, miniatura e aviso local de tipo/tamanho*
- [x] Upload funcionando no MinIO (dev) — *17/09: og_image + preview via admin → `service_name: s3`, objeto no bucket `launch-os-dev`*
- [x] Upload funcionando no bucket real (produção) — *17/09 na 1.9: PDF (290 KB) e capa (1 MB) em `launch-os-prod` via admin, `service_name: s3`, 403 sem assinatura*
- [x] Variants pré-processados (`preprocessed: true`) — *já definidos na 1.3; o `TransformJob` roda no Sidekiq no upload (antes ainda de publicar); conferido `processed? == true` em dev*
- [x] Spec: upload em request spec com fixtures; rejeição de tipo/tamanho inválidos — *`spec/requests/admin/product_uploads_spec.rb` (13 exemplos)*
- [x] Confirmar: objeto no bucket não acessível sem assinatura (403) — *`GET http://localhost:9000/launch-os-dev/<key>` → 403*

### 1.6 Landing page — spec [06](../specs/06-landing-page.md)
- [x] Rota `GET /:slug` por último em `routes.rb`, com constraint
- [x] `LandingPagesController#show` (`Product.published`, 404 caso contrário, `fresh_when`) — *`stale?(@product, public: true)` + `expires_in 60s, public`; `belongs_to :product, touch: true` nas coleções para o ETag invalidar (anexos e Action Text já dão touch)*
- [x] Partials do template `direct_response`: hero, problem, benefits, whats_inside, previews, testimonials, offer, guarantee, faq, final_cta, footer — *`app/views/landing_pages/templates/direct_response/`; rodapé em `shared/_footer` pelo layout `landing` (serve às demais páginas públicas)*
- [x] Blocos opcionais somem quando vazios
- [x] Bloco `#buy` com `data-module="checkout"` e `data-*` (botão PayPal entra na 2.1; por ora placeholder) — *`modules/checkout.js` é um stub com `init` vazio; o placeholder é um botão desabilitado "opening soon"*
- [x] Campo telefone + opt-in renderizado só com `TWILIO_ENABLED=true`
- [x] Meta tags: title, description, og:*, canonical, robots — *`og:image` = variant `:og` 1200×630 **JPEG** (scraper do Facebook e WebP não combinam) ou a imagem do hero na falta de og_image; URL absoluta via proxy*
- [x] `modules/sticky_cta.js` (barra mobile após o hero) — *some enquanto `#hero` ou `#buy` estão visíveis (IntersectionObserver)*
- [x] Imagens com variants WebP, `loading="lazy"`, width/height — *`lp_image_tag` calcula width/height dos metadados do blob (após o AnalyzeJob); hero é `eager` + `fetchpriority=high`*
- [x] Rodapé com suporte e links legais — *links `/privacy`, `/terms`, `/refund-policy` (rotas na 1.8)*
- [x] Lighthouse mobile ≥ 85 / acessibilidade ≥ 90 — *17/09 em produção (Chrome nativo): 100/100/100/100, LCP 1,4 s, CLS 0. Em dev (Chrome amd64 emulado + servidor de dev sem gzip): Accessibility **100**, SEO **100**, Performance 68 (TBT/main-thread do emulador; LCP 1,8 s, CLS 0, 73 KB no total, JS próprio 5,6 KB). o emulador amd64 dava 68–71, número descartado*
- [x] Specs: `spec/requests/landing_pages_spec.rb` (T14) — *12 exemplos; system spec fica opcional*
- [ ] ✅ Critérios de aceite da spec 06 — *feitos: blocos/opcionais, 375/1280 px sem overflow (screenshots headless), 404 amigável (Rails), slug reservado. Faltam: botão PayPal em mobile (2.1), Lighthouse em produção e Facebook Debugger (1.9)*
- Decisões: (1) imagens públicas pelo **proxy** do Active Storage (`resolve_model_to_route = :rails_storage_proxy`): URL estável e cacheável pelo Thruster, sem 302 por imagem, e o navegador em dev não precisa resolver `minio`. (2) `allow_browser versions: :modern` saiu de `ApplicationController` e ficou só no admin — na LP devolveria 406 a compradores com navegador in-app antigo. (3) `config/importmap.rb` restringe `preload` por entry: a LP não pré-carrega trix/actiontext/módulos do admin (antes baixava 526 KB de Trix); layout `landing` carrega só `tailwind` + `application.css`. (4) `@plugin "@tailwindcss/typography"` (embutido no CLI standalone) para o Action Text da LP (`prose`).

### 1.7 Preview de rascunho
- [x] `Admin::ProductsController#preview` renderizando o mesmo template com `@preview = true` — *`GET /admin/products/:slug/preview`, layout `landing`, sem o locale pt-BR do admin (a página é a pública tal qual) e sem cache público; links "Preview" e "Ver ao vivo" (só publicado) na tela do produto*
- [x] Banner "DRAFT PREVIEW", tracking desligado, botão de compra desabilitado — *`_preview_banner` (status + voltar ao admin), `robots noindex,nofollow`, bloco `#buy` sem `data-module="checkout"` (SDK nunca carrega); tracking ainda não existe (3.1) e já nasce condicionado a `@preview`*
- [x] Spec: preview 200 para draft/archived; público 404 (T14) — *em `spec/requests/admin/products_spec.rb`; o 404 público está em `landing_pages_spec`*

### 1.8 Páginas legais — spec [14](../specs/14-paginas-legais.md)
- [x] `LegalPagesController` com `/privacy`, `/terms`, `/refund-policy` — *layout `landing`, `Cache-Control public, max-age=1h`; refund aceita `?product=<slug>` (o rodapé da LP passa) e usa `refund_days` do produto, senão 14*
- [x] Textos em inglês cobrindo os itens mínimos da spec (dados coletados, PayPal/Twilio/SES/Meta/GA, cookies, CCPA/LGPD, reembolso com `refund_days`) — *views em `app/views/legal_pages/` com moldura `_page`. **Conferir**: operador escrito como "DevBatista (Rafael Batista), based in Brazil" — ajustar para a razão social/CNPJ se o contador pedir; retenção "typically 5 years" e logs 90 dias são premissas*
- [x] `last_updated` visível; links no rodapé de todas as páginas públicas — *datas em `LegalPagesController::LAST_UPDATED` (atualizar ao mudar o texto); rodapé `shared/_footer` usa as rotas*
- [x] Spec: 200 nas três rotas; não capturadas por `/:slug` — *`spec/requests/legal_pages_spec.rb` (8 exemplos)*
- [x] Critérios da spec 14 que dependem do site no ar: URL da privacy aceita pela Meta; email de suporte recebe/responde teste — *ambos em 17/09 (ver 1.9)*

### 1.9 Cadastrar e publicar o produto
- [x] Produto *21-Day Procrastination Reset* cadastrado em produção com copy provisória, mockup e PDF placeholder — *17/09 pelo admin de produção (admin criado via seed com `ADMIN_EMAIL`/`ADMIN_PASSWORD` no Railway; a senha pode sair do Railway depois). Sem depoimentos de propósito: os do seed são fictícios — só entram depoimentos reais*
- [x] Publicado; `https://www.devbatista.online/21-day-procrastination-reset` responde 200 — *17/09: 200 com ETag e `public, max-age=60`; legais 200; `/nao-existe` 404. Lighthouse mobile em produção (Chrome nativo): **Performance 100, Accessibility 100, Best Practices 100, SEO 100**; LCP 1,4 s, CLS 0, 73 KB. PDF e capa no bucket `launch-os-prod` (S3), 403 sem assinatura*
- [x] Facebook Sharing Debugger mostra og:image e description corretos — *17/09: 200, canônica, og:title/description/image/alt lidos; único aviso é `fb:app_id` ausente (opcional, não temos app na Meta e não precisamos — Pixel/CAPI se configuram no Events Manager). A capa atual é um placeholder (foto sem relação com o produto): **trocar por mockup real + OG 1200×630 antes dos anúncios***
- [x] Política de privacidade aceita pela Meta — *não existe campo para cadastrar a URL no Business Manager; a exigência é o link no rodapé da LP, já presente. `https://www.devbatista.online/privacy` só é digitada se a revisão do anúncio (Fase 4) ou a Página do Facebook pedir*
- [x] Email de suporte: enviar um teste para `support@devbatista.online` e responder (spec 14) — *17/09: recebe e responde*

**M1 — LP em produção (04/10):** critérios de saída da Fase 1 no cronograma.

---

## Fase 2 — Pagamento e entrega (S3–S4 · 05/10–18/10)

### 2.1 Checkout PayPal (create/capture) — spec [07](../specs/07-checkout-paypal.md)
- [x] `Providers::Paypal::Client` (Faraday): `access_token` com cache em Redis, `create_order`, `capture_order`, `get_order`, `verify_webhook_signature`; `PayPal-Request-Id`; timeouts; erros → `TransientError`/`PermanentError` — *`ApiError < PermanentError` com `status`, `error_name`, `details` e `issue?`; cache por `expires_in − 60 s` (em dev o `memory_store` é por processo)*
- [x] `spec/support/paypal_stubs.rb` — *tag `:paypal` injeta credenciais de teste em ENV*
- [x] Migration `orders` (todas as colunas da spec, índices únicos em `paypal_order_id`/`paypal_capture_id`) + migration `clients` — *+ `orders.pending_reason` (motivo do capture PENDING)*
- [x] `Order` (enum status, `event_id` no `before_create`), `Client` (normalizes email, phonelib) — *`Product#deletable?` passa a exigir zero pedidos; `has_many :orders, dependent: :restrict_with_exception`*
- [x] Factories `orders` (traits por status, `:with_attribution`, `:with_whatsapp_opt_in`) e `clients`
- [x] `Checkout::PaypalController#create`: produto publicado, phone E.164, `Order.create!` com preço do backend, `CreateOrder`, retorna `paypal_order_id`; rate limit — *`skip_forgery_protection` em vez de `null_session`: sem token válido o `null_session` zera o cookie jar e perde `lo_attr`/`_fbp`/`_fbc` (visto no servidor de dev); spec 07 atualizada*
- [x] `Checkout::PaypalController#capture`: idempotente, trata COMPLETED/PENDING/outros, `ORDER_ALREADY_CAPTURED` — *COMPLETED → `Orders::MarkPaid`; PENDING grava `paypal_capture_id` + `pending_reason`; outros → `MarkFailed` + 422. `thank_you_url` vem `nil` até a 2.4*
- [x] `modules/checkout.js`: IntersectionObserver → carrega SDK → `Buttons` com createOrder/onApprove/onError — *mensagens inline (sucesso/pending/erro); placeholder some quando o SDK renderiza*
- [x] `modules/tracking.js` (wrappers no-op por enquanto)
- [x] Compra Sandbox pelo navegador chega ao capture COMPLETED — *17/09: `paid`, `paypal_capture_id`, `Client` John Doe (US), líquido USD 14.02. **Achado**: as primeiras compras voltaram `PENDING` com `RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION` — a conta business (BRL) estava com aceite manual de outras moedas; resolvido em *Preferências de pagamento → "Sim, aceitar e converter"*. **Fazer o mesmo na conta Live antes do go-live** (registrado na spec 07)*
- [x] Specs: `spec/requests/checkout/paypal_spec.rb` (T01 parcial, T04, T16, T17, T22), `spec/services/providers/paypal/client_spec.rb` — *+ `create_order_spec`, `orders/mark_paid_spec` (T01, T12, T25), `mark_failed_spec`, `models/order_spec`, `models/client_spec`*
- [x] ✅ Critérios de aceite da spec 07 (parte de create/capture) — *feitos: amount adulterado ignorado; capture 2× idempotente; tudo com WebMock; compra completa (token + `DeliverOrderJob` → email) fechada na 2.4/2.6*

### 2.2 Webhook PayPal — spec [07](../specs/07-checkout-paypal.md)
- [x] Migration `webhook_events` com índice único `(provider, external_id)` — *modelo `WebhookEvent` (enum status, `mark_processed!/ignored!/failed!`); `Order has_many :webhook_events`*
- [x] `Webhooks::PaypalController` (`ActionController::API`): verifica assinatura, `find_or_create_by!`, 400 se inválida, enfileira job, 200 rápido — *`Providers::Paypal::VerifyWebhookSignature` (sem os 5 headers PAYPAL-* → inválido sem chamar a API); evento inválido gravado como `ignored` com `error: "invalid signature"`; corpo sem id/event_type → 400*
- [x] `ProcessPaypalWebhookJob` (fila `webhooks`): roteia por `event_type`, `retry_on`/`discard_on`, marca `processed`/`failed` — *COMPLETED → MarkPaid (no-op se já pago pelo front), PENDING grava motivo, DENIED → MarkFailed, REFUNDED/REVERSED → MarkRefunded, DISPUTE.CREATED → MarkDisputed (por `seller_transaction_id`), DISPUTE.RESOLVED → `Orders::ResolveDispute`, APPROVED só correlaciona; `InvalidTransition` → evento `failed` sem derrubar o job. `MarkRefunded`/`MarkDisputed`/`ResolveDispute` adiantados da 2.3 (sem token/email, que entram na 2.4/2.6)*
- [x] `PAYPAL_WEBHOOK_SKIP_VERIFY` só em development (erro no boot se em production) — *`config/initializers/paypal.rb`*
- [x] Túnel HTTPS (cloudflared/ngrok) + webhook cadastrado no PayPal Developer com todos os eventos — *serviço `tunnel` no compose (perfil `tunnel`, cloudflared quick tunnel, sem conta); `development.rb` libera `*.trycloudflare.com`; webhook Sandbox `4T3411320U005420J` criado **via API** com os 8 eventos. A URL do quick tunnel muda a cada subida e o túnel cai de tempos em tempos: atualizar com `PATCH /v1/notifications/webhooks/:id`. Lição: `docker compose restart` não relê o `.env` — usar `up -d`*
- [x] Webhook real do Sandbox recebido e gravado em `webhook_events` — *18/09: reembolso feito pela API → `PAYMENT.CAPTURE.REFUNDED` entregue pelo PayPal via túnel, assinatura verificada, job no Sidekiq, pedido `refunded`. Também cobre o critério "refund no Sandbox" da spec 07 (token/email na 2.4/2.6)*
- [x] Specs: `spec/requests/webhooks/paypal_spec.rb` (T02, T03), `spec/jobs/process_paypal_webhook_job_spec.rb` (T05, T17) — *+ `services/orders/transitions_spec` (T07, T18, T25), `models/webhook_event_spec`*

### 2.3 Client e Order — services de transição — spec [07](../specs/07-checkout-paypal.md)
- [x] `Orders::InvalidTransition` — *na 2.1 (`app/services/orders.rb`)*
- [x] `Orders::MarkPaid` (with_lock, idempotente, find_or_create Client, opt-in, token, enfileira `DeliverOrderJob`) — *2.1/2.4/2.6: with_lock, idempotente, Client com opt-in (texto TCPA do i18n), token criado/regenerado; `DeliverOrderJob` enfileirado **depois do commit** e só na transição (idempotência cobre o job)*
- [x] `Orders::MarkFailed` (✅ na 2.1), `Orders::MarkRefunded` (revoga token, email), `Orders::MarkDisputed`, resolução de disputa — *2.2/2.4/2.6: transições, revogação/regeneração do token e email `refund_confirmation` enfileirado após o commit*
- [ ] Fallback: capture server-side se `CHECKOUT.ORDER.APPROVED` sem capture após 10 min (opcional)
- [ ] Specs: `spec/services/orders/mark_paid_spec.rb` (T01, T12), `mark_refunded_spec.rb` (T07), `mark_disputed_spec.rb` (T18), `mark_failed_spec.rb`, T25 em cada

### 2.4 DownloadToken, Thank You, download — spec [08](../specs/08-entrega-download-tokens.md)
- [x] Migration `download_tokens`; modelo com `has_secure_token`, `active?`, `inactive_reason`, `revoke!`, `regenerate!` — *+ `register_download!` (incremento sob lock), `remaining_downloads`; defaults de `DOWNLOAD_TOKEN_TTL_DAYS`/`DOWNLOAD_MAX_COUNT`. Precedência: revogado antes de não-pago (refund/disputa → 410, não 402). Ligado às transições: `MarkPaid` cria (ou regenera após disputa ganha), `MarkRefunded`/`MarkDisputed` revogam. O capture PENDING já cria o token (inativo) para a Thank You mostrar "processing"*
- [x] Factory com traits `:expired`, `:revoked`, `:limit_reached` — *+ `:unpaid`*
- [x] `ThankYouController#show` (pending / pago / inativo), `no-store`, marca `purchase_tracked_at` na 1ª visita — *renderiza `data-module="tracking" data-event="purchase"` só nessa visita (o disparo real é a 4.1); `noindex`. **Decisão 18/09**: a Thank You é por `/thank-you/:order_id` e **não mostra o link de download** — ele vai só por email/WhatsApp (2.6/2.7); a página só confirma o pagamento e diz para onde o link foi. Specs 08 e 12 atualizadas*
- [x] `DownloadsController#show`: lock + incremento, redirect para URL assinada (5 min), 410/429, rate limit — *402 para não-pago; `include ActiveStorage::SetCurrent` (serviço Disk nos testes); página `downloads/unavailable` com partial `shared/_token_unavailable` reutilizado pela Thank You*
- [x] Download do PDF real funcionando em dev (MinIO) — *18/09: redirect `X-Amz-Expires=300` + `attachment; filename="<slug>.pdf"`, PDF servido, contador 1; URL assinada de 1 s → 403 após expirar; objeto sem assinatura → 403. Em produção confirmar na primeira compra real (S3 já validado 403 na 1.9)*
- [x] Download do PDF real funcionando em produção — *19/09: compra Sandbox em produção → pedido pago, token ativo, email pelo SES real; `/download/:token` → 303 para URL assinada do bucket `launch-os-prod` → PDF (3 páginas, 297 KB). Achados: (1) o comprador sandbox padrão tem email fake → bounce no SES; usar conta sandbox com email customizado nos próximos testes; (2) `PAYPAL_WEBHOOK_ID` do Railway aponta para o túnel de dev — produção ainda não recebe webhooks*
- [x] Specs: `spec/requests/thank_you_spec.rb` (T21), `spec/requests/downloads_spec.rb` (T06), `spec/models/download_token_spec.rb`

### 2.5 Recuperação de acesso — spec [08](../specs/08-entrega-download-tokens.md)
- [x] `AccessRecoveriesController` new/create; resposta idêntica exista ou não; honeypot; rate limit por IP e por hash de email — *18/09: `rate_limit` 5/10 min por IP e 3/h por SHA-256 do email normalizado (`name: "email"`); honeypot `website` + timestamp assinado no form (`MIN_FILL_SECONDS = 2`) — bot recebe a mesma resposta, sem reenvio; email inválido → 422 no próprio form; log só com IP/found/resent (nunca o email). Links `/access/recover` hardcoded (Thank You, token inativo, mailer) trocados por `access_recover_path/url`*
- [x] `Delivery::ResendAccess` (regenera token se expirado/limite; não se revogado por refund/disputa) — *entregue na 2.6; aqui só ligado ao controller (um call por pedido pago do cliente)*
- [x] Spec: `spec/requests/access_recoveries_spec.rb` (T19, T26) — *+ honeypot/tempo/token forjado, multi-pedido (reembolsado e revogado ficam de fora), limite por email ignorando caixa/espaços. Smoke em dev: pedido pago com token expirado → form → token regenerado → `access_resend` no `/letter_opener`*

### 2.6 Jobs, email (SES), MessageLog — spec [09](../specs/09-notificacoes-email-whatsapp.md)
- [x] Migration `message_logs`; modelo e factory — *enums string (channel/template/status), `mark_sent!`, `register_attempt!`, `mark_failed!`; `Order has_many :message_logs` (destroy), `Client` (nullify)*
- [x] `Providers::Ses::Client#send_raw_email` (`aws-sdk-sesv2`, `configuration_set_name`, erros mapeados) + `spec/support/ses_stubs.rb` — *SDK com `stub_responses` e `retry_limit: 0` nos specs; classes de erro conferidas no SDK (não existe `ServiceUnavailable` no SESv2) e registradas na spec 09*
- [x] `DeliveryMethods::SesApi` registrado como `:ses_api` (`initializers/action_mailer.rb`); ativo só em production — *registro em `to_prepare` (classe recarregável); grava o Message-ID do SES no `mail.message_id`*
- [x] `OrderMailer#delivery`, `#access_resend`, `#refund_confirmation` (HTML + texto, reply_to suporte) — *parametrizado (`with(order:)`); destinatário `"Nome <email>"`; botão vai para `/download/:token` (decisão 18/09 da spec 08); `ApplicationMailer` lê `MAIL_FROM`/`SUPPORT_EMAIL`*
- [x] Previews em `spec/mailers/previews/` — *`/rails/mailers/order_mailer` com o último pedido pago do banco de dev (`preview_paths` em development.rb)*
- [x] `DeliverOrderJob` → `SendAccessEmailJob` (+ WhatsApp na 2.7); `SendAccessEmailJob` com `MessageLog` e retry 3× — *o job de email ficou **`SendOrderEmailJob(order_id, template:)`**, único para os 3 templates; retry reaproveita o mesmo log `queued`; esgotado ou erro permanente → `failed` + Sentry*
- [x] `Delivery::DeliverOrder` e `Delivery::ResendAccess` ligados aos jobs — *`ResendAccess` já pronto para a 2.5: cria/regenera token (nunca se revogado), enfileira `access_resend`*
- [x] Email chegando em `/letter_opener` após compra Sandbox — *18/09: pedido pago do dia → `DeliverOrderJob` → `SendOrderEmailJob` no Sidekiq (fila `mailers`), `MessageLog` `sent`, link do email → 303 para a URL assinada do MinIO (lembrar `127.0.0.1 minio` no `/etc/hosts` para abrir no navegador). Refund pela API → webhook → email `refund_confirmation` também no `/letter_opener`*
- [x] Em produção: SES fora do sandbox; email de teste na caixa de entrada com DKIM/SPF alinhados — *18/09: `OrderMailer#delivery` disparado via `railway ssh` com objetos em memória (nada salvo) → entregue em 14 s na caixa de entrada; SPF PASS (envelope `@ses.devbatista.online`, custom MAIL FROM), DKIM PASS (`devbatista.online` + `amazonses.com`), DMARC PASS (`p=QUARANTINE`); `Reply-To` suporte, `Feedback-ID` do configuration set `launch-os`. Dica: o `railway ssh` perde aspas — mandar comandos sem `sh -c "..."`*
- [x] Specs: `spec/mailers/order_mailer_spec.rb`, `spec/jobs/deliver_order_job_spec.rb` (T09), `spec/jobs/send_access_email_job_spec.rb` — *+ `delivery_methods/ses_api_spec`, `providers/ses/client_spec`, `delivery/resend_access_spec`, `models/message_log_spec`; `mark_paid_spec`/`transitions_spec` cobrem o enfileiramento após commit*

### 2.7 WhatsApp via Twilio — spec [09](../specs/09-notificacoes-email-whatsapp.md)
- [x] `initializers/twilio.rb`; `TWILIO_ENABLED` respeitado em toda a cadeia — *18/09: boot falha se ligado sem SID/token/from/template; `Delivery.whatsapp_enabled?`/`whatsapp?(order)` gateiam LP, `DeliverOrder`, `ResendAccess`, job e botão do admin*
- [x] `Providers::Twilio::Client` (Faraday, `POST .../Messages.json`, Basic Auth, form-encoded; `valid_signature?` com HMAC-SHA1 + `secure_compare`) — conferir nomes dos parâmetros na doc oficial — *`From`/`To` (`whatsapp:+E164`)/`ContentSid`/`ContentVariables` (JSON)/`StatusCallback`; 201 → `sid`; `ApiError` com `code` (21xxx/63xxx permanentes), 20429/20500/20503 e 5xx transitórios*
- [x] `Whatsapp::SendTemplateMessage` (monta variáveis e chama o provider) — *`{{3}}` é o `/download/:token` (decisão 18/09); callback e link públicos via `Delivery.url_options`; exige token ativo*
- [x] `SendWhatsappMessageJob` (fila `whatsapp`, `MessageLog`, retry só em erros transitórios, sem retry em 63xxx) — *mesmo desenho do `SendOrderEmailJob`; log fica `queued` até o callback; `error_code` gravado*
- [x] `Webhooks::TwilioController#status` e `#inbound` com `RequestValidator`; STOP → opt-out; inbound encaminhado por email ao suporte (`SupportMailer`) — *`WebhookEvent` por callback (reentrega → 204), `MessageLog` atualizado com timestamps/`ErrorCode`; STOP/UNSUBSCRIBE/CANCEL/END/QUIT; TwiML vazio; `SupportMailer#inbound_whatsapp` (pt-BR, link do cliente no painel)*
- [x] Opt-in gravado no `Client` com texto e data/hora — *desde a 2.1 (`MarkPaid`)*
- [x] `spec/support/twilio_stubs.rb` (WebMock em `api.twilio.com`) — *tag `:twilio` liga o canal com credenciais de teste; `post_twilio_webhook` assina como a Twilio*
- [ ] Teste real no Sandbox da Twilio: mensagem recebida; callback `delivered` gravado; STOP funciona — *pendente: criar o Content Template no Sandbox (categoria Utility, texto da spec 09) e pôr o `HX…` em `TWILIO_TEMPLATE_ORDER_DELIVERY_SID`; `join <código>` do celular; `APP_HOST`/`APP_PROTOCOL` apontando para o túnel; cadastrar `/webhooks/twilio/status` e `/inbound` no Sandbox; então compra com telefone + opt-in*
- [x] Specs: `spec/jobs/send_whatsapp_message_job_spec.rb` (T08, T10, T27), `spec/requests/webhooks/twilio_spec.rb` (T08, T11, T20) — *+ `providers/twilio/client_spec` (T29), `whatsapp/send_template_message_spec`, `support_mailer_spec`; 316 exemplos verdes*
- [ ] ✅ Critérios de aceite da spec 09 — *todos os automatizáveis marcados; falta só o teste real no Sandbox (mensagem recebida, `queued → sent → delivered`)*

### 2.8 Admin de pedidos, clientes e webhook events — spec [11](../specs/11-admin-pedidos-clientes-dashboard.md)
- [x] `Admin::OrdersController` index (filtros, busca, Pagy) e show (atribuição, token mascarado, mensagens, eventos) — *18/09: filtros por status/produto/período, busca por email (parcial) ou ids do PayPal (exatos), coluna de canais com o último `MessageLog` por canal, disputa em destaque. **Paginação própria** (`Admin::Paginated`, 25/página) no lugar do Pagy — decisão registrada na spec 11*
- [x] Ações: `resend` (email/whatsapp), `regenerate_token`, `revoke_token`, `resolve_dispute` — *`resend` via `Delivery::ResendAccess` (recusa revogado; WhatsApp só com opt-in + `TWILIO_ENABLED`); `resolve_dispute` via `Orders::ResolveDispute` (`outcome=paid|refunded`); tudo com `data-confirm` e 303*
- [x] `Admin::ClientsController` index/show, `revoke_whatsapp_opt_in`, telefone mascarado — *`+1 ••• ••• 2671` via Phonelib; contagem de pedidos pagos por subquery; busca por email/nome; filtro de opt-in*
- [x] `Admin::WebhookEventsController` index/show (payload bruto) — *filtros por provedor/status; payload e headers em JSON formatado*
- [x] Sidekiq Web em `/admin/sidekiq` com constraint de sessão — *sem cookie válido → 404; link na sidebar; produto → resumo de pedidos no show*
- [x] Specs: `spec/requests/admin/orders_spec.rb`, `spec/requests/admin/clients_spec.rb`, acesso sem sessão → redirect — *+ `webhook_events_spec`, `sidekiq_web_spec`; 295 exemplos verdes*

**M2 — Compra Sandbox ponta a ponta (18/10):** critérios de saída da Fase 2 no cronograma.

---

## Fase 3 — Polimento do admin (adiantado: a partir de 19/09, ~6 h)

Decisão de 18/09: o polimento visual que estava na 1.4 ("fazer quando o painel ganhar as primeiras telas reais") vira
uma fase própria, agora que produtos, pedidos, clientes e webhook events existem. Sem spec própria; a referência é a
spec [11](../specs/11-admin-pedidos-clientes-dashboard.md) (painel simples, server-rendered, ERB + Tailwind, sidebar).

### 3.1 Visual do admin
**Decisão 19/09:** referência visual = template Conca (Aqlova), reimplementado em Tailwind (nada copiado — é Bootstrap/jQuery e comercial). Tokens e componentes `adm-*` em `tailwind/application.css`; detalhes na spec 11 ("Visual e tema").
- [x] Sidebar: hierarquia, item ativo, área do usuário, responsivo (colapsa no mobile) — *seções Loja/Sistema com ícones (Heroicons inline), item ativo violeta, usuário + sair no rodapé; drawer com backdrop no mobile (`modules/admin/sidebar.js`)*
- [x] Cabeçalhos de página, breadcrumbs e barras de ação consistentes (produto, pedido, cliente, evento) — *partial `admin/shared/_page_header` (breadcrumb, título + badges, subtítulo, ações em bloco); header fixo de 60 px com título curto, tema e "Ver site"*
- [x] Tabelas: densidade, alinhamento numérico, linhas clicáveis, estados vazios com CTA, paginação — *`adm-table` com hover, `adm-num` tabular, `adm-empty`, paginação com borda; linha em disputa/falha em `adm-row-danger`*
- [x] Formulários do produto: agrupamento em seções, ajuda inline, erros, campos de arquivo e coleções (benefícios/depoimentos/FAQs) — *cards por seção, `adm-label`/`adm-input`/`adm-hint`, Trix com o mesmo input (e toolbar legível no escuro), coleções e anexos nos tokens*
- [x] Flashes (notice/alert) e confirmações (`data-confirm`) com o mesmo padrão visual — *`adm-alert-*` com ícone; avisos de página (disputa, capture pendente, falta para publicar) no mesmo componente*
- [x] Badges e helpers (`button_classes`, `input_classes`, `badge`) como fonte única de estilo — nada de classes soltas repetidas — *`badge(label, tom)` com 6 tons; `dl_row`; `icon`; zero `gray-*/blue-*/red-*` nas views do admin*
- [x] Login: tela alinhada ao restante do painel — *layout "cover" do Conca (`auth-login-cover`): painel violeta com boas-vindas + mockup do produto publicado, form com logo, e-mail e senha com "olho" (`modules/admin/password_toggle.js`); sem social/"esqueci a senha"/cadastro*
- [x] Conferir no mobile (≥ 375 px) e no desktop; sem regressão nos specs de request/views — *screenshots via Selenium/Chromium na rede do compose (1366×900 e 390×844, claro e escuro); 316 exemplos verdes*
- [x] **Tema escuro** (pedido de 19/09) — *tokens em `html[data-theme="dark"]` + `prefers-color-scheme`; botão no header (`modules/admin/theme.js`, `localStorage`)*
- [x] Dashboard com 4 totais reais (pagos, faturamento, clientes, pendentes/disputas) como placeholder até a 4.3

---

## Fase 4 — Tracking, testes e go-live (S5 · 19–25/10)

### 4.1 Atribuição, Pixel, PageVisit — spec [10](../specs/10-tracking-e-analytics.md)
- [x] `modules/attribution.js` (cookie `lo_attr` first-touch, 30 dias) + `lo_vid` — *19/09: first-touch com UTMs/fbclid/referrer externo/landing_path; `lo_vid` UUID 1 ano; dispara o beacon `POST /visits`*
- [x] `Tracking::AttributionCapture` lendo cookie/params/`_fbp`/`_fbc` no checkout → `Order` — *já existia no `Checkout::PaypalController#attribution` desde a 2.1 (T22); mantido lá em vez de um service*
- [x] Migration `page_visits`; `RecordPageVisitJob` (ignora bots, `ip_hash`) — *`PageVisit` (bot?, `ip_hash` com sal diário, scope `humans`), `VisitsController` (beacon, sem CSRF, 60/min por IP). **Decisão:** contar por beacon, não no controller da LP — o Thruster cacheia a LP (spec 10)*
- [x] Snippet do Pixel com nonce (só com `META_PIXEL_ID` e sem preview): PageView, ViewContent — *sem inline: `<body data-module="tracking" data-pixel-id>` e o `tracking.js` cria o stub `fbq`, carrega `fbevents.js`, `init` + `PageView`; `ViewContent` pelo `<main data-event="view_content">` com `content_ids/value/currency`*
- [x] `InitiateCheckout` no `onClick` do botão; `Purchase` na Thank You com `eventID = order.event_id`, uma vez — *`#buy` ganhou `data-product-name/value/currency`; Thank You manda `eventID` + `transaction_id` (GA4) — o disparo único já era garantido pelo servidor (T21)*
- [x] Banner de cookies simples (`lo_consent`) — *`shared/_consent_banner` + `modules/consent.js`, fora do preview*
- [x] Meta Test Events: três eventos recebidos com value/currency — *19/09, em produção (conjunto `LaunchOS` 2908081392894300, Eventos de teste → Site → "Abrir site" na LP): `ViewContent` 21:16:38 → `InitiateCheckout` 21:16:42 → `PageView` + `Purchase` 21:16:59 com identificação do evento = `order.event_id` (dedup pronta para a Conversions API). Conferido também em Chromium limpo: `PageView` e `ViewContent` saem nessa ordem. Achado: o conjunto `LaunchOS` fica no portfólio `DevBatista` — trocar o portfólio no seletor do Events Manager se ele não aparecer na lista*
- [x] Specs: T22 em `checkout/paypal_spec.rb`, T21 em `thank_you_spec.rb`, `spec/jobs/record_page_visit_job_spec.rb` — *+ `requests/visits_spec` (beacon, bot, rate limit), `models/page_visit_spec`, LP spec (Pixel com/sem id, preview, consent). Navegador real (Chromium via Selenium): cookies `lo_attr`/`lo_vid`/`_fbp`/`_fbc`, `fbevents.js` carregado e fila vazia, first-touch mantido na 2ª visita, 2 `PageVisit` gravadas, consent gravado*

### 4.2 GA4, Sentry, monitoramento, hardening — spec [13](../specs/13-seguranca.md)
- [x] GA4 (`view_item`, `begin_checkout`, `purchase` único) — *20/09: `tracking.js` carrega o `gtag/js` pelo mesmo módulo do Pixel (`<body data-ga4-id>` só com `GA4_MEASUREMENT_ID`, fora do preview); os eventos já saíam pelos wrappers. Verificado em Chromium sob a CSP (`config` + `view_item` no dataLayer). Sem propriedade GA4 criada ainda — a variável fica vazia em produção*
- [ ] Sentry recebendo erro de teste; integração Sidekiq (dead jobs) — *código pronto: `sentry-sidekiq` com `report_after_job_retries = true` (só reporta quando as retentativas acabam) e `report-uri` da CSP apontando ao Sentry. Falta o erro de teste em produção após o deploy (`Sentry.capture_message` via `railway ssh`)*
- [ ] Uptime monitor ativo; backup diário confirmado e **restauração testada**; versionamento do bucket — *UptimeRobot ativo desde 16/09; versionamento do bucket ativo desde a Fase 0. **Decisão 20/09:** `pg_dump` para o bucket em vez do Railway Pro — `Backups::DatabaseDump` + `rake backup:database|list|download`, retenção 30; restauração testada em dev (dump → MinIO → `pg_restore` → contagens iguais). Falta: criar o serviço cron no Railway (`0 6 * * *`, `bin/rails backup:database` — README) e rodar/restaurar um dump de produção*
- [x] CSP com nonces (PayPal, Meta, GA); headers de segurança; `config.hosts`; `filter_parameters` — *20/09: CSP com nonce em `script-src` e `style-src`, sem `unsafe-inline` (importmap com nonce, Trix lê a `<meta csp-nonce>`, SDK do PayPal recebe `data-csp-nonce`); `object-src 'none'`, `frame-ancestors 'none'`; `Permissions-Policy` via `default_headers` (o DSL do Rails 8.1 só emite `Feature-Policy`); `filter_parameters` + `phone`/`from`/`to`/`body`/`name`; `config.hosts` e HSTS já estavam. Verificado em Chromium: LP com botões do PayPal, Pixel e GA4 + admin com Trix e tema — zero violações; `spec/requests/security_headers_spec.rb`*
- [x] `brakeman` e `bundler-audit` limpos; Dependabot ativo — *já rodavam no CI (`scan_ruby`, `scan_js` = `importmap audit`); `.github/dependabot.yml` bundler + actions semanal. 20/09: 0 warnings, 0 vulnerabilidades*
- [x] Checklist da spec 13 percorrido item a item — *20/09: 32 de 35 marcados com a evidência ao lado de cada um. Testes manuais em produção: webhook forjado → 400, bucket sem assinatura → 403. Ficam abertos: páginas legais coerentes (C.5), revisão por segunda pessoa e a adulteração de valor via DevTools (T04 cobre; manual na 4.5)*

### 4.3 Dashboard — spec [11](../specs/11-admin-pedidos-clientes-dashboard.md)
- [ ] `Admin::DashboardsController#show` com período e filtro por produto
- [ ] Cards: visitas, únicos, checkouts, vendas, faturamento bruto/líquido estimado, taxas, reembolsos, entregas
- [ ] Vendas por `utm_campaign`/`utm_content`; últimos pedidos; alertas (webhooks/mensagens falhas, disputas)
- [ ] Spec: `spec/requests/admin/dashboards_spec.rb` com uma compra refletida
- [ ] *(Pode ir para a Fase 6 se faltar tempo — registrar no cronograma)*

### 4.4 Plano de testes — spec [15](../specs/15-plano-de-testes.md)
- [ ] Matriz T01–T30 conferida: cada caso tem spec e está verde
- [ ] SimpleCov ≥ 90% em services/jobs/webhooks
- [ ] `rubocop` + `rubocop-rspec` sem ofensas
- [ ] Manuais 1–4 executados e registrados em `docs/qa/` (compra Sandbox desktop + mobile, refund Sandbox, Twilio Sandbox + STOP, webhook real via túnel)
- [ ] Falhas corrigidas

### 4.5 Go-live — spec [00](../specs/00-visao-geral.md), [13](../specs/13-seguranca.md)
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

## Fase 5 — Campanha (S6 · 26/10–01/11)

- [ ] 5.1 Campanha criada manualmente (vendas, Purchase, Advantage+, EUA, inglês, 3 anúncios, R$ 18/dia)
- [ ] 5.1 Três anúncios aprovados pela Meta
- [ ] 5.2 Planilha diária preenchida (seção 8 do cronograma) — dias 1 a 7
- [ ] 5.3 Sentry, `MessageLog` e disputas verificados diariamente; suporte respondido em < 24 h
- [ ] 5.4 Análise final e cenário escolhido (seção 9 do cronograma) — 03/11

**M4 (26/10) e M5 (03/11).**

---

## Fase 6 — Pós-validação (sem datas)

Ver ordem sugerida no cronograma (seção 4.8). Não iniciar antes de M5.
