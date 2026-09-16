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
| Aplicação | http://localhost:3000 |
| Health check | http://localhost:3000/up |
| Emails enviados (dev) | http://localhost:3000/letter_opener |
| Console do MinIO | http://localhost:9001 (`minio` / `minio12345`) |

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

Após alterar o `Gemfile`: `docker compose run --rm web bundle install` (atualiza o `Gemfile.lock` e o volume de gems).

Links assinados do Active Storage em dev apontam para `http://minio:9000`. Para abri-los no navegador do host,
adicione `127.0.0.1 minio` ao `/etc/hosts`.

## Produção (Railway)

Deploy por `Dockerfile` (ver `railway.json`). Dois serviços a partir deste repositório:

- **web** — comando padrão da imagem; o Railway injeta `PORT` e o entrypoint roda `db:prepare` no boot.
- **worker** — *Custom Start Command*: `bundle exec sidekiq -C config/sidekiq.yml`.

Mais os plugins **Postgres** (`DATABASE_URL`) e **Redis** (`REDIS_URL`). Variáveis obrigatórias e passo a passo
em [docs/specs/02-docker-e-ambiente.md](docs/specs/02-docker-e-ambiente.md#produção--railway).
