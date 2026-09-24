# Launch OS — Especificações do MVP

Plataforma própria para vender produtos digitais (PDF) no mercado americano.
Primeiro produto: **21-Day Procrastination Reset** (US$ 14.90).

Estas specs derivam do documento *MVP — Venda de Produtos Digitais nos EUA v2.0* (DevBatista, set/2026)
e o traduzem em decisões técnicas prontas para implementação.

## Stack fixada

| Item | Decisão |
|---|---|
| Runtime | 100% Docker (dev, teste e produção) |
| Framework | Ruby on Rails **8.1.3** |
| Ruby | 3.4.x |
| Banco | PostgreSQL 17 |
| Jobs | Sidekiq 8 + Redis 7 |
| Cache | Redis (`redis_cache_store`, mesmo Redis do Sidekiq) |
| Arquivos | Active Storage + bucket S3-compatível privado (MinIO em dev) |
| Frontend | ERB server-rendered + **JavaScript puro** (módulos ES via importmap), Propshaft, Tailwind CSS — **sem Hotwire/Turbo/Stimulus**, sem Node |
| Pagamento | PayPal Orders API v2 + Webhooks |
| Email | **Amazon SES via API** (`aws-sdk-sesv2`) em produção — `letter_opener_web` em dev |
| WhatsApp | Twilio WhatsApp Business API — REST API oficial via Faraday (sem gem) |
| Ads / Analytics | Meta Pixel + GA4 |
| Erros | Sentry |
| Testes | RSpec (`rspec-rails`) + FactoryBot + WebMock; Capybara para system specs |

## Índice

| # | Spec | Conteúdo |
|---|---|---|
| 00 | [Visão geral](00-visao-geral.md) | Objetivo, hipóteses, escopo (dentro/fora), definição de pronto |
| 01 | [Arquitetura e stack](01-arquitetura-e-stack.md) | Estrutura da app, gems, variáveis de ambiente, credenciais |
| 02 | [Docker e ambiente](02-docker-e-ambiente.md) | Dockerfile, compose dev/prod, serviços auxiliares, comandos |
| 03 | [Modelo de dados](03-modelo-de-dados.md) | Tabelas, colunas, índices, relacionamentos, enums, migrations |
| 04 | [Autenticação admin](04-autenticacao-admin.md) | User, sessão, lockout, rate limit |
| 05 | [Catálogo (admin)](05-catalogo-produtos-admin.md) | CRUD de Product, blocos da LP, uploads, status |
| 06 | [Landing page](06-landing-page.md) | Template Direct Response, rota por slug, preview, SEO, performance |
| 07 | [Checkout PayPal](07-checkout-paypal.md) | Create/capture, webhook, idempotência, máquina de estados do Order |
| 08 | [Entrega e download](08-entrega-download-tokens.md) | DownloadToken, Thank You, download protegido, recuperação de acesso |
| 09 | [Notificações](09-notificacoes-email-whatsapp.md) | Mailers, Twilio, templates, MessageLog, callbacks |
| 10 | [Tracking e analytics](10-tracking-e-analytics.md) | UTMs, Meta Pixel, GA4, event_id, PageVisit |
| 11 | [Admin: pedidos, clientes, dashboard](11-admin-pedidos-clientes-dashboard.md) | Listagens, reenvio, revogação, métricas |
| 12 | [Rotas](12-rotas.md) | Tabela completa de rotas e controllers |
| 13 | [Segurança](13-seguranca.md) | Checklist obrigatório antes de ir ao ar |
| 14 | [Páginas legais](14-paginas-legais.md) | Privacy, Terms, Refund Policy, suporte |
| 15 | [Plano de testes](15-plano-de-testes.md) | Casos de teste → arquivos de teste |
| 16 | [Roadmap e fases](16-roadmap-e-fases.md) | Ordem de desenvolvimento, cronograma, fase 2 (Meta Marketing API) |
| 17 | [Glossário](17-glossario.md) | Termos de marketing, pagamento e mensageria |
| 18 | [Fiscal, recibos e câmbio](18-fiscal-e-recibos.md) | Recibo individual, PTAX, período fiscal, relatório e NF-e consolidada |

## Convenções destas specs

- **MUST / DEVE**: obrigatório no MVP. **SHOULD / DEVERIA**: recomendado, pode ser adiado com justificativa. **MAY / PODE**: opcional.
- Nomes de classes, tabelas, colunas e rotas estão em inglês (código). Texto explicativo em português.
- Todo texto visível ao comprador (LP, emails, WhatsApp, páginas legais) é em **inglês americano**.
- Valores monetários são armazenados em **centavos (integer)** + `currency` (ISO 4217). Nunca float.
- Timestamps sempre em UTC no banco; exibição no admin em `America/Sao_Paulo`.
- Cada spec termina com uma seção **Critérios de aceite** — é o que fecha a tarefa.

## Princípio orientador

> Nascer simples, mas com `Product` como núcleo. Tudo que não for indispensável para vender e entregar o
> primeiro PDF fica para depois da validação (ver [00-visao-geral.md](00-visao-geral.md), seção "Fora do escopo").
