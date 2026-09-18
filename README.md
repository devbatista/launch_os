# Launch OS

Plataforma própria para vender produtos digitais (PDF) no mercado americano.
Primeiro produto: **21-Day Procrastination Reset**.

Rails 8.1 · PostgreSQL 17 · Sidekiq + Redis · Active Storage (S3/MinIO) · PayPal · Amazon SES · Twilio WhatsApp · Meta Pixel.
Tudo roda em containers; não é preciso Ruby, Postgres ou Node na máquina.

- Especificações: [docs/specs/](docs/specs/README.md)
- Cronograma e registro de decisões: [docs/cronograma/](docs/cronograma/README.md)
- Checklist de execução: [docs/checklist/](docs/checklist/README.md)
- Regras para agentes de IA: [AGENTS.md](AGENTS.md)

## Desenvolvimento

Pré-requisitos: Docker Desktop (ou Docker Engine + Compose v2).

```bash
cp .env.example .env                                 # valores locais já preenchidos
docker compose build
docker compose run --rm web bin/setup                # cria os bancos
docker compose up                                    # web, sidekiq, css, db, redis, minio
```

| Serviço | URL |
|---|---|
| Aplicação | http://localhost:3100 |
| Health check | http://localhost:3100/up |
| Emails enviados (dev) | http://localhost:3100/letter_opener |
| Console do MinIO | http://localhost:9001 (`minio` / `minio12345`) |

As portas do host são definidas no `.env` (`WEB_PORT`, `DB_PORT`, `REDIS_PORT`, `MINIO_PORT`, `MINIO_CONSOLE_PORT`)
para não conflitar com outros projetos; ao mudar `WEB_PORT`, ajuste `APP_HOST` junto.

Comandos comuns (sempre dentro do container):

```bash
docker compose exec web bin/rails console
docker compose exec web bin/rails db:migrate
docker compose exec web bin/rails g model Product ...
docker compose exec -T web bundle exec rspec        # suíte de testes
docker compose exec -T web bin/rubocop
docker compose exec -T web bin/brakeman
docker compose restart sidekiq                      # após editar um job (o worker não recarrega código)
docker compose logs -f sidekiq
```

Webhooks em dev (PayPal/Twilio): `bin/tunnel` sobe o quick tunnel do Cloudflare e já aponta o webhook do PayPal
(`PAYPAL_WEBHOOK_ID` do `.env`, ver spec 02) para a URL nova. O quick tunnel some sozinho depois de algumas horas
(`Tunnel not found` no log) — rode `bin/tunnel` de novo antes de testar compra/refund. Ao mudar o `.env`,
`docker compose up -d web sidekiq` (`restart` não relê o arquivo).

Após alterar o `Gemfile`: `docker compose run --rm web bundle install` (atualiza o `Gemfile.lock` e o volume de gems).

Links assinados do Active Storage em dev apontam para `http://minio:9000`. Para abri-los no navegador do host,
adicione `127.0.0.1 minio` ao `/etc/hosts`.

## Produção (Railway)

Deploy por `Dockerfile`; a configuração de cada serviço fica no dashboard do Railway (o *Config as Code* foi
descontinuado pela plataforma). Dois serviços a partir deste repositório:

- **launch_os** (web) — comando padrão da imagem, healthcheck em `/up`; o Railway injeta `PORT` e o entrypoint roda `db:prepare` no boot.
- **sidekiq** — *Custom Start Command*: `bundle exec sidekiq -C config/sidekiq.yml`, sem healthcheck.

Mais os plugins **Postgres** (`DATABASE_URL`) e **Redis** (`REDIS_URL`). Variáveis obrigatórias e passo a passo
em [docs/specs/02-docker-e-ambiente.md](docs/specs/02-docker-e-ambiente.md#produção--railway).
