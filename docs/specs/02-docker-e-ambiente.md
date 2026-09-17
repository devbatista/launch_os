# 02 — Docker e ambiente

Regra: **nada roda fora de container**. Nem Ruby, nem Postgres, nem Node/Tailwind. O desenvolvedor
precisa apenas de Docker + Docker Compose.

## Arquivos

```
Dockerfile              # produção (gerado pelo Rails 8, ajustado) — usado pelo Railway
Dockerfile.dev          # desenvolvimento/teste (com gems de dev, sem precompile)
compose.yml             # dev (nome canônico do Compose v2; equivale a docker-compose.yml)
railway.json            # serviço web: builder DOCKERFILE, health check /up, restart policy
railway.sidekiq.json    # serviço sidekiq: mesmo builder, startCommand do Sidekiq, sem health check
.dockerignore           # exclui .env*, master.key, docs/, AGENTS.md, compose.yml
.env.example            # versionado; copiar para .env (gitignored)
```

## Dockerfile.dev

```dockerfile
FROM ruby:3.4-slim

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential git libpq-dev libvips pkg-config curl postgresql-client libyaml-dev \
  && rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/usr/local/bundle \
    RAILS_ENV=development \
    BOOTSNAP_CACHE_DIR=/tmp/bootsnap

WORKDIR /launch_os
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
```

`libvips` é necessário para `image_processing` (variants WebP).

## Dockerfile (produção)

Usar o gerado por `rails new` (multi-stage, usuário não-root, Thruster) com dois ajustes:

1. Adicionar `libvips` e `postgresql-client` na etapa final.
2. `bin/docker-entrypoint` exporta `HTTP_PORT="${PORT:-${HTTP_PORT:-80}}"` (Railway injeta `PORT`; Thruster
   escuta em `HTTP_PORT`) e executa `bin/rails db:prepare` quando o comando é `./bin/thrust ./bin/rails server`.
3. O diretório de trabalho do container de dev é `/launch_os` (não `/rails`: `rails new` usa o nome da pasta
   como nome da aplicação, e `Rails` é uma constante reservada).
4. `Procfile.dev`/foreman removidos: web, sidekiq e css são serviços separados do compose.

`SECRET_KEY_BASE_DUMMY=1` no `assets:precompile` (já vem no Dockerfile padrão).

## compose.yml (desenvolvimento)

```yaml
services:
  db:
    image: postgres:17
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes: [pgdata:/var/lib/postgresql/data]
    ports: ["5432:5432"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      retries: 10

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes: [redisdata:/data]
    ports: ["6379:6379"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 10

  minio:
    image: quay.io/minio/minio   # MinIO saiu do Docker Hub; usar o Quay
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minio
      MINIO_ROOT_PASSWORD: minio12345
    volumes: [miniodata:/data]
    ports: ["9000:9000", "9001:9001"]

  minio-init:
    image: quay.io/minio/mc
    depends_on: [minio]
    entrypoint: >
      /bin/sh -c "
      mc alias set local http://minio:9000 minio minio12345 &&
      mc mb -p local/launch-os-dev &&
      mc anonymous set none local/launch-os-dev || true"

  web: &rails
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: bin/rails server -b 0.0.0.0
    env_file: .env
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/launch_os_development
      REDIS_URL: redis://redis:6379/0
    volumes:
      - .:/launch_os
      - bundle:/usr/local/bundle
    ports: ["3000:3000"]
    depends_on:
      db: { condition: service_healthy }
      redis: { condition: service_healthy }
      minio: { condition: service_started }
    stdin_open: true
    tty: true

  sidekiq:
    <<: *rails
    command: bundle exec sidekiq -C config/sidekiq.yml
    ports: []
    depends_on:
      db: { condition: service_healthy }
      redis: { condition: service_healthy }

  css:
    <<: *rails
    command: bin/rails tailwindcss:watch
    ports: []
    depends_on: []

volumes:
  pgdata:
  redisdata:
  miniodata:
  bundle:
```

Notas:
- `sidekiq` é um serviço separado com a mesma imagem e o mesmo `.env` do `web` (âncora YAML `&rails`).
  Reinicia automaticamente ao editar código? Não — Sidekiq não recarrega classes; após alterar um job,
  `docker compose restart sidekiq`.
- `redis` persiste em volume (`appendonly`) para não perder jobs enfileirados ao reiniciar o compose.
- `stdin_open`/`tty` permitem `binding.irb`/`debug` via `docker compose attach web`.
- Volume `bundle` evita reinstalar gems a cada rebuild.
- Não há serviço de email em dev: `letter_opener_web` grava os emails em `tmp/letter_opener` (dentro do
  volume `.:/launch_os`) e os exibe em `http://localhost:3000/letter_opener`. Como o Sidekiq roda em outro
  container mas compartilha o mesmo volume, emails enviados por jobs também aparecem lá.

## `.env.example`

```
APP_HOST=localhost:3000
APP_PROTOCOL=http
REDIS_URL=redis://redis:6379/0
SIDEKIQ_CONCURRENCY=5
SUPPORT_EMAIL=support@devbatista.online
MAIL_FROM="DevBatista <no-reply@devbatista.online>"

S3_ENDPOINT=http://minio:9000
S3_BUCKET=launch-os-dev
S3_REGION=us-east-1
S3_ACCESS_KEY_ID=minio
S3_SECRET_ACCESS_KEY=minio12345
S3_FORCE_PATH_STYLE=true

# Email: em dev não precisa de nada (letter_opener_web). Em produção (API do SES):
# SES_REGION=us-east-1
# SES_ACCESS_KEY_ID=
# SES_SECRET_ACCESS_KEY=
# SES_CONFIGURATION_SET=launch-os
# MAIL_DOMAIN=devbatista.online

PAYPAL_ENV=sandbox
PAYPAL_CLIENT_ID=
PAYPAL_CLIENT_SECRET=
PAYPAL_WEBHOOK_ID=

TWILIO_ENABLED=false
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_WHATSAPP_FROM=whatsapp:+14155238886
TWILIO_TEMPLATE_ORDER_DELIVERY_SID=

META_PIXEL_ID=
GA4_MEASUREMENT_ID=
SENTRY_DSN=

DOWNLOAD_TOKEN_TTL_DAYS=7
DOWNLOAD_MAX_COUNT=10
```

## `config/storage.yml`

```yaml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

s3:
  service: S3
  endpoint: <%= ENV["S3_ENDPOINT"] %>
  bucket: <%= ENV["S3_BUCKET"] %>
  region: <%= ENV.fetch("S3_REGION", "auto") %>
  access_key_id: <%= ENV["S3_ACCESS_KEY_ID"] %>
  secret_access_key: <%= ENV["S3_SECRET_ACCESS_KEY"] %>
  force_path_style: <%= ENV["S3_FORCE_PATH_STYLE"] == "true" %>
  public: false
```

Development e production usam `:s3` (dev aponta para MinIO). URLs assinadas geradas pelo container
apontam para `minio:9000`; para o navegador do host resolver, adicionar `127.0.0.1 minio` em `/etc/hosts`
ou usar `S3_ENDPOINT=http://localhost:9000` com `network_mode` adequado. Documentar no README do projeto.

## Comandos do dia a dia

| Ação | Comando |
|---|---|
| Subir tudo | `docker compose up` |
| Setup inicial | `docker compose run --rm web bin/setup` |
| Console | `docker compose exec web bin/rails console` |
| Migrations | `docker compose exec web bin/rails db:migrate` |
| Testes | `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec` |
| Um arquivo / linha | `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/services/orders/mark_paid_spec.rb:42` |
| System specs | `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/system` (requer serviço `selenium`; ver abaixo) |
| Lint | `docker compose run --rm web bin/rubocop` |
| Segurança | `docker compose run --rm web bin/brakeman` |
| Gerador | `docker compose exec web bin/rails g model Product ...` |
| Logs de jobs | `docker compose logs -f sidekiq` |
| Reiniciar worker após editar um job | `docker compose restart sidekiq` |
| Painel do Sidekiq | `http://localhost:3000/admin/sidekiq` (requer login admin) |
| Emails enviados em dev | `http://localhost:3000/letter_opener` |
| Limpar Redis (dev) | `docker compose exec redis redis-cli FLUSHALL` |

System specs: adicionar serviço `selenium/standalone-chromium` no compose (perfil `test`, `docker compose --profile test up selenium`)
e configurar Capybara com driver `remote` (`SELENIUM_URL=http://selenium:4444`, `Capybara.server_host = "0.0.0.0"`,
`Capybara.app_host = "http://web:#{Capybara.server_port}"`). Opcionais no MVP; request specs cobrem o crítico.

## Webhooks em desenvolvimento

PayPal e Twilio precisam de URL HTTPS pública para entregar webhooks. Usar um túnel
(`cloudflared tunnel --url http://localhost:3000` ou ngrok) como serviço adicional do compose ou
manualmente, e cadastrar a URL gerada no PayPal Developer / Twilio console.

## Produção — Railway

Hospedagem decidida: **Railway**, deploy por `Dockerfile` (projeto gerado com `--skip-kamal`).
`railway.json` na raiz fixa o builder `DOCKERFILE`, o health check em `/up` e a política de restart.

Serviços no projeto Railway (todos a partir do mesmo repositório):

| Serviço | Origem | Comando | Observações |
|---|---|---|---|
| `web` | repo (Dockerfile) | padrão da imagem (`./bin/thrust ./bin/rails server`) | Railway injeta `PORT`; `bin/docker-entrypoint` exporta `HTTP_PORT=$PORT` para o Thruster e roda `db:prepare` antes de subir |
| `sidekiq` | repo (Dockerfile) | `bundle exec sidekiq -C config/sidekiq.yml` via **`railway.sidekiq.json`** (Settings → Config-as-code → *Config File Path*) | mesma imagem e mesmas variáveis do `web`; não roda migrations. Precisa do config próprio porque o `railway.json` da raiz vale para todo serviço do repo e traria o health check `/up`, que o Sidekiq não atende |
| `Postgres` | plugin Railway | — | fornece `DATABASE_URL` (referenciar como `${{Postgres.DATABASE_URL}}`) |
| `Redis` | plugin Railway | — | fornece `REDIS_URL` (`${{Redis.REDIS_URL}}`) |

Variáveis obrigatórias em `web` e `sidekiq`: `RAILS_MASTER_KEY`, `DATABASE_URL`, `REDIS_URL`, `APP_HOST`,
`APP_PROTOCOL=https`, `S3_*`, `SES_*`, `PAYPAL_*`, `TWILIO_*`, `META_PIXEL_ID`, `GA4_MEASUREMENT_ID`, `SENTRY_DSN`,
`SUPPORT_EMAIL`, `MAIL_FROM`, `MAIL_DOMAIN`. Usar *shared variables* do Railway para não duplicar entre os dois serviços.

### Domínio e DNS (HostGator, sem Cloudflare)

Decisão (16/09): o domínio `devbatista.online` **permanece registrado na Namecheap com DNS na HostGator**;
nameservers e registrador não mudam. Consequências:

- O Railway só aceita **CNAME** para domínio customizado e a zona da HostGator não suporta CNAME/ALIAS no apex.
  Portanto a aplicação vive em **`www.devbatista.online`**; o apex `devbatista.online` redireciona (301) para
  `https://www.devbatista.online` por um *redirect* configurado no cPanel da HostGator.
- Todas as URLs públicas (LP, Thank You, webhooks, `return_url` do PayPal, canonical, políticas) usam `www`.
  `APP_HOST=www.devbatista.online`.
- `config.hosts` em production: `www.devbatista.online`, `devbatista.online` e `*.up.railway.app` (health check).
- Não há CDN/proxy na frente do Railway; o cache HTTP da LP fica por conta do Thruster + headers do Rails.
- O email existente da HostGator (`MX mail.devbatista.online`, SPF `websitewelcome.com`) **não é alterado**; o SES
  usa um subdomínio próprio para o MAIL FROM (ver [09](09-notificacoes-email-whatsapp.md)).

Registros a criar na zona DNS da HostGator (cPanel → *Zone Editor*):

| Tipo | Nome | Valor | Para |
|---|---|---|---|
| CNAME | `www` | alvo fornecido pelo Railway ao adicionar o domínio (ex.: `xxxx.up.railway.app`) | aplicação |
| TXT | nome/valor fornecidos pelo Railway junto com o CNAME | verificação de posse — **obrigatório**; sem ele o domínio responde 404 mesmo com o CNAME resolvendo | verificação Railway |
| Redirect (cPanel) | `devbatista.online` → `https://www.devbatista.online` | 301, com *wildcard* | apex → www |
| CNAME ×3 | `<token>._domainkey` | valores do Easy DKIM do SES | assinatura DKIM |
| MX + TXT | `ses` (MAIL FROM `ses.devbatista.online`) | `feedback-smtp.us-east-1.amazonses.com` / `v=spf1 include:amazonses.com -all` | alinhamento SPF |
| TXT | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:dmarc@devbatista.online` | DMARC |
| TXT | `@` | verificação de domínio da Meta (ou meta tag na LP) | Business Manager |

O `www` já existe hoje como CNAME para o apex — precisa ser **substituído** pelo alvo do Railway. Certificado TLS
é emitido automaticamente pelo Railway após o CNAME propagar (minutos a algumas horas na HostGator).

Por que o apex não pode apontar direto (documentação oficial do Railway, *Working with domains*): o Railway
fornece apenas um alvo CNAME (`*.up.railway.app`) e um TXT de verificação — não há IP fixo nem registro `A`.
Domínio raiz exige provedor com CNAME flattening (Cloudflare), ALIAS (DNSimple) ou ANAME; a zona da HostGator
não tem nenhum dos três. Um `A` apontando para algum IP do Railway não é suportado e quebra a qualquer redeploy.
Se um dia o apex precisar responder direto, a única forma é mover o DNS para um provedor com CNAME flattening —
fora do escopo por decisão registrada.

Deploy: push na branch principal → build da imagem → health check em `/up` → troca. Migrations rodam no boot do
`web` (entrypoint). Com uma única instância `web` isso é seguro; se escalar para mais de uma, mover o
`db:prepare` para um *pre-deploy command* do Railway.

Requisitos obrigatórios:
- Redis com persistência (AOF) ou gerenciado; um worker Sidekiq sempre ativo (webhooks dependem dele).
- HTTPS com renovação automática.
- Backup diário do Postgres (recurso da plataforma ou `pg_dump` agendado para o bucket).
- Versionamento habilitado no bucket.
- `RAILS_MASTER_KEY` e demais segredos como variáveis do host.

## CI (GitHub Actions — recomendado)

Workflow com serviço `postgres:17` (Redis não é necessário: testes usam adapter `:test`), build da imagem de dev, `bin/rails db:prepare`, `bundle exec rspec`,
`bin/rubocop`, `bin/brakeman`, `bundle audit`. Rails 8.1 traz `bin/ci` (`config/ci.rb`) — usar, trocando o
step de testes por `bundle exec rspec`.

## Critérios de aceite

- [ ] Clone limpo + `cp .env.example .env` + `docker compose up` + `bin/setup` → app em `http://localhost:3000`.
- [ ] Upload de imagem no admin aparece no bucket do MinIO (`localhost:9001`).
- [ ] Email de teste (enviado via job no container `sidekiq`) aparece em `localhost:3000/letter_opener`.
- [ ] Job enfileirado é processado pelo serviço `sidekiq` (visível em `docker compose logs sidekiq` e em `/admin/sidekiq`).
- [ ] Parar o `sidekiq`, enfileirar um job, subir de novo → job processado (persistência do Redis).
- [ ] Imagem de produção builda com `docker build .` e sobe com `RAILS_MASTER_KEY` + `DATABASE_URL`.
