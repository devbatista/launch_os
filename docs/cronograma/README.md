# Cronograma — MVP Venda de Produtos Digitais nos EUA

Documento vivo de acompanhamento. Base: *Cronograma de Desenvolvimento MVP* (DevBatista, set/2026)
e as specs em [docs/specs/](../specs/README.md).

| | |
|---|---|
| **Início do desenvolvimento** | 21/09/2026 (S1) |
| **Campanha no ar** | 26/10/2026 (M4) |
| **Decisão** | 03/11/2026 (M5) |
| **Capacidade** | 1 dev (DevBatista), ~25 h/semana |
| **Semana atual** | S0 — Contas e aprovações |
| **Última atualização** | 2026-09-16 |
| **Status geral** | 🟦 no prazo |

## Como usar

- Atualizar o **status** de cada tarefa conforme avança; preencher **Concluído em** e **Horas reais** ao fechar.
- **Sexta-feira**: revisão semanal (seção 10) — recalcular horas restantes e confirmar o marco da fase.
- **Terça-feira**: checkpoint de aprovações externas (seção 6).
- Qualquer mudança de escopo, prazo ou stack vai para o **Registro de decisões** (seção 11), com data.
- Item novo que não está no MVP vai para a Fase 6, nunca para as fases 1–5.

Legenda de status: ⬜ não iniciado · 🟦 em andamento · ✅ concluído · ⏸ bloqueado (dizer por quê) · ⏭ adiado para Fase 6 · ❌ cancelado

## 1. Painel

| Fase | Período | Semanas | Horas plan. | Horas reais | Progresso | Status |
|---|---|---|---|---|---|---|
| Fase 0 — Contas e aprovações | 14/09 – 20/09 | S0 | 11 | | 3/5 (0.2, 0.4, 0.5 ✅; 0.1 aguarda verificação PayPal; 0.3 Sender adiado) | 🟦 |
| Fase 1 — Base | 21/09 – 04/10 | S1–S2 | 46 | | 9/9 — concluída em 17/09 (M1) | ✅ |
| Fase 2 — Pagamento e entrega | 05/10 – 18/10 | S3–S4 | 48 | | 7/8 código entregue em 17–18/09; 2.7 aguarda teste real no Sandbox da Twilio; M2 pendente | 🟦 |
| Fase 3 — Polimento do admin | 19/09 (adiantado) | S1 | 6 | | 1/1 | ✅ |
| Fase 4 — Tracking, testes e go-live | 19/10 – 25/10 | S5 | 23 | | 0/5 | ⬜ |
| Trilha de conteúdo (paralela) | 21/09 – 25/10 | S1–S5 | 45 (fora do dev) | | 0/6 | ⬜ |
| Fase 5 — Campanha de validação | 26/10 – 01/11 | S6 | 7 | | 0/3 | ⬜ |
| Análise e decisão | 02/11 – 03/11 | S7 | 4 | | 0/1 | ⬜ |
| Fase 6 — Pós-validação | a definir | — | — | | — | ⬜ |

Total de desenvolvimento (Fases 0–4): **134 h** em 6 semanas. Folga de ~15% já embutida.
**Decisão 18/09:** o polimento visual do admin (antes um item da 1.4) virou a Fase 3; as fases seguintes foram renumeradas (tracking/testes/go-live = Fase 4, campanha = Fase 5, pós-validação = Fase 6). Datas e marcos M1–M5 não mudaram.
Feriados considerados: 12/10 (S4) e 02/11 (S7).

> **Se a capacidade cair para 20 h/semana:** tudo desliza ~1 semana (Fase 2 → 25/10, go-live → 01/11,
> campanha → 02/11). A ordem das tarefas não muda. Registrar na seção 11 se acontecer.

## 2. Marcos

| Marco | Data | Critério de aceite | Status | Atingido em |
|---|---|---|---|---|
| **M0** — Contas prontas | 20/09 | PayPal, Meta, Twilio, hospedagem, domínio, SES e Sentry criados; aprovações solicitadas | ⬜ | |
| **M1** — LP em produção | 04/10 | Admin com login; produto cadastrado e visível em `www.devbatista.online/21-day-procrastination-reset`; páginas legais publicadas | ✅ | 17/09 — 17 dias antes da meta. Lighthouse mobile 100/100/100/100. Debugger da Meta e email de suporte ok — Fase 1 concluída |
| **M2** — Compra Sandbox ponta a ponta | 18/10 | Pagamento Sandbox confirmado por webhook; Order `paid`; email e WhatsApp entregues; download funciona; webhook duplicado não duplica pedido | ⬜ | |
| **M3** — Definição de pronto | 25/10 | Todos os itens de [00-visao-geral](../specs/00-visao-geral.md#definição-de-pronto-mvp) verdadeiros; compra real controlada confirmada; eventos validados no Events Manager | ⬜ | |
| **M4** — Campanha no ar | 26/10 | Três anúncios aprovados pela Meta e ativos, R$ 18/dia | ⬜ | |
| **M5** — Decisão | 03/11 | Relatório com métricas (17.3) e cenário (17.4) escolhido; próximo orçamento definido ou teste encerrado | ⬜ | |

## 3. Linha do tempo

█ desenvolvimento · ▒ espera externa · ▓ conteúdo · ░ campanha/análise

| Trilha | S0<br>14–20/09 | S1<br>21–27/09 | S2<br>28/09–04/10 | S3<br>05–11/10 | S4<br>12–18/10 | S5<br>19–25/10 | S6<br>26/10–01/11 | S7<br>02–08/11 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Criar contas (0.1–0.5) | █ | | | | | | | |
| Aprovação PayPal Business | ▒ | ▒ | | | | | | |
| Aprovação WhatsApp Sender + template | ▒ | ▒ | ▒ | ▒ | | | | |
| Saída do sandbox SES | ▒ | ▒ | | | | | | |
| Verificação de domínio / conta de anúncios | ▒ | ▒ | | | | | | |
| Projeto Rails, Docker, deploy, User (1.1–1.2) | | █ | | | | | | |
| Product, associações, CRUD admin (1.3–1.4) | | █ | █ | | | | | |
| Uploads, template LP, legais, cadastro (1.5–1.9) | | | █ | | | | | |
| PayPal Sandbox, webhook, Client, Order (2.1–2.3) | | | | █ | | | | |
| Token, Thank You, recuperação, email (2.4–2.6) | | | | █ | █ | | | |
| WhatsApp, admin pedidos/clientes (2.7–2.8) | | | | | █ | | | |
| Polimento do admin (3.1) — adiantado | | █ | | | | | | |
| Pixel, UTMs, GA4, Sentry, dashboard (4.1–4.3) | | | | | | █ | | |
| Plano de testes, PayPal Live, compra real (4.4–4.5) | | | | | | █ | | |
| Escrever e revisar PDF + tracker (C.1–C.3) | | ▓ | ▓ | ▓ | ▓ | | | |
| Copy da LP, mockup, políticas (C.4–C.5) | | | ▓ | ▓ | | | | |
| Três criativos (C.6) | | | | | ▓ | ▓ | | |
| Campanha no ar (5.1–5.3) | | | | | | | ░ | |
| Análise e decisão (5.4) | | | | | | | | ░ |

## 4. Tarefas

Coluna **Spec** aponta para o arquivo em `docs/specs/` que detalha a tarefa. Ajustes de stack em relação
ao PDF original estão marcados com ⚙️ (ver seção 11).

### 4.1 Fase 0 — Contas e aprovações (14/09 – 20/09) · sem código

| ID | Tarefa | Spec | Horas | Depende de | Status | Concluído em | Notas |
|---|---|---|---|---|---|---|---|
| 0.1 | Conta PayPal Business, verificar identidade, app no PayPal Developer (Sandbox + Live), anotar credenciais | [07](../specs/07-checkout-paypal.md) | 2 | — | 🟦 | | 16/09: conta CNPJ criada, verificação enviada (2–4 dias úteis); app Sandbox `launch_os` + contas de teste prontas; credenciais no `.env` e no Railway. Falta só o app Live (bloqueado até a verificação) |
| 0.2 | Meta Business, conta de anúncios com método de pagamento, Pixel, verificação do domínio `devbatista.online` | [10](../specs/10-tracking-e-analytics.md) | 2 | 0.4 (DNS) | ✅ | 16/09 | Portfólio e conta de anúncios `DevBatista` já existiam; cartão adicionado; conjunto de dados `LaunchOS` (`META_PIXEL_ID` no `.env`/Railway); domínio verificado por TXT. AEM fica para a 3.1 |
| 0.3 | Conta Twilio, solicitar WhatsApp Sender vinculado ao Meta Business, submeter template `order_delivery` (Utility), ativar Sandbox | [09](../specs/09-notificacoes-email-whatsapp.md) | 2 | 0.2 | 🟦 | | 16/09: subconta `launch_os` criada, Sandbox WhatsApp ativo e testado. **Sender e template adiados** (upgrade Twilio exige US$ 20 pré-pagos); plano B `TWILIO_ENABLED=false`. Reavaliar até 04/10 |
| 0.4 | Domínio no Cloudflare, hospedagem (container), PostgreSQL + Redis gerenciados, bucket privado S3/R2, ⚙️ **Amazon SES**: identidade de domínio, Easy DKIM, MAIL FROM, DMARC, pedido de saída do sandbox | [02](../specs/02-docker-e-ambiente.md), [09](../specs/09-notificacoes-email-whatsapp.md) | 4 | — | ✅ | 16/09 | Railway (Postgres 18 + Redis, sem backup automático — plano Hobby), app em `https://www.devbatista.online`; SES verificado e fora do sandbox, config set `launch-os`; bucket S3 `launch-os-prod`; `S3_*`/`SES_*` no Railway; caixa `support@` recebendo; DMARC `p=quarantine` após teste do SES com SPF/DKIM/DMARC PASS |
| 0.5 | Conta Sentry, monitor de uptime, repositório Git | [13](../specs/13-seguranca.md) | 1 | — | ✅ | 16/09 | Sentry org `devbatista` / projeto `launch_os` (`SENTRY_DSN` no `.env`/Railway); UptimeRobot em `/up` a cada 5 min; repo privado com CI e Dependabot. GA4 fica para a Fase 3 |

**Total: 11 h**

### 4.2 Fase 1 — Base (21/09 – 04/10)

| ID | Tarefa | Spec | Horas | Depende de | Status | Concluído em | Notas |
|---|---|---|---|---|---|---|---|
| 1.1 | Projeto Rails 8.1.3 (`--skip-solid --skip-hotwire --skip-test`), ⚙️ Docker dev/prod + compose (db, redis, sidekiq, minio), ⚙️ RSpec/FactoryBot/WebMock, CI, deploy inicial com HTTPS, credentials e ENV | [01](../specs/01-arquitetura-e-stack.md), [02](../specs/02-docker-e-ambiente.md) | 6 | 0.4 | 🟦 | | Iniciada em 16/09 (antes da S1). Feito: projeto, Docker, compose, Sidekiq/S3/UUID, deploy no Railway com domínio, RSpec/FactoryBot/WebMock/SimpleCov, importmap + `data-module`, layouts, `Providers::*Error`, Sentry, `config.hosts`, CI com RSpec. Serviço `sidekiq` no Railway no ar (17/09). Resta só o critério da spec 02 que depende de upload/email/jobs |
| 1.2 | `User`: `has_secure_password`, login/logout, lockout após 5 tentativas, rate limit no login, layout do admin | [04](../specs/04-autenticacao-admin.md) | 6 | 1.1 | ✅ | 17/09 | Gerador de autenticação adaptado ao namespace `/admin`; lockout, rate limit (429), sidebar, seed do admin. Pin `json < 3` (ActiveSupport 8.1.3 quebra cookies assinados com json 3) |
| 1.3 | `Product` + `Benefit`, `Testimonial`, `Faq`: migrations, validações, slug único, status draft/published/archived, factories | [03](../specs/03-modelo-de-dados.md) | 6 | 1.1 | ✅ | 17/09 | Action Text + Active Storage (uuid), `Positioned`, validação de anexos, regra de publicação, seed de dev com placeholders; 80 specs verdes |
| 1.4 | CRUD admin de produtos e dos blocos da LP, com ordenação (⚙️ JS puro + fetch, sem Turbo) | [05](../specs/05-catalogo-produtos-admin.md) | 6 | 1.2, 1.3 | 🟦 | | 17/09: CRUD, publish/unpublish/archive, coleções aninhadas com `nested_list.js` (fetch + partial, fallback sem JS), `confirm.js`, admin em pt-BR (`rails-i18n`). Falta só polir o visual (junto da 1.5) |
| 1.5 | Uploads Active Storage em bucket privado: PDF, capa, mockup, og_image, previews; validação de tipo/tamanho; variants WebP | [05](../specs/05-catalogo-produtos-admin.md) | 5 | 1.3 | ✅ | | 17/09: seção Arquivos no admin com remoção individual, `file_preview.js`, MinIO ok (403 sem assinatura). Falta só confirmar no bucket de produção (na 1.9); bucket de produção confirmado na 1.9 (403 sem assinatura) |
| 1.6 | Template Direct Response: rota `/:slug`, todos os blocos, mobile first, meta tags e og_image, entry `landing.js` | [06](../specs/06-landing-page.md) | 10 | 1.4, 1.5 | 🟦 | | 17/09: rota `/:slug`, template `direct_response` completo, sticky CTA, meta/OG, cache ETag, imagens via proxy, preload por entry no importmap. Faltam Lighthouse em produção (1.9) e botão PayPal (2.1) |
| 1.7 | Preview de rascunho para admin; 404 público para não publicados | [05](../specs/05-catalogo-produtos-admin.md), [06](../specs/06-landing-page.md) | 2 | 1.6 | ✅ | | 17/09: preview com banner, noindex e compra desabilitada; links Preview/Ver ao vivo no admin |
| 1.8 | Páginas legais (Privacy, Terms, Refund Policy) e contato de suporte, em inglês | [14](../specs/14-paginas-legais.md) | 3 | 1.6 | ✅ | | 17/09: três páginas em inglês, refund lê `refund_days` do produto, rodapé com as rotas. Faltam Facebook BM e teste do email (1.9); Meta e email verificados na 1.9 |
| 1.9 | Cadastrar o *21-Day Procrastination Reset* com copy provisória e publicar em produção | [16](../specs/16-roadmap-e-fases.md) | 2 | 1.6, 1.8 | ✅ | | 17/09: produto cadastrado e publicado em produção; LP 200; Lighthouse 100/100/100/100. Facebook Debugger e email de suporte ok em 17/09 — tarefa fechada |

**Total: 46 h (≈ 23 h/semana)**

### 4.3 Fase 2 — Pagamento e entrega (05/10 – 18/10)

| ID | Tarefa | Spec | Horas | Depende de | Status | Concluído em | Notas |
|---|---|---|---|---|---|---|---|
| 2.1 | PayPal Sandbox: `Providers::Paypal::Client`, `POST /checkout/paypal` (create) e `/capture`, `modules/checkout.js` com SDK na LP, preço sempre do backend | [07](../specs/07-checkout-paypal.md), [06](../specs/06-landing-page.md) | 8 | 1.9, 0.1 | 🟦 | | 17/09 (S1!): client PayPal, Order/Client, create/capture, checkout.js; compra Sandbox COMPLETED. Falta só o critério que depende de 2.4/2.6. Achado: preferência de moeda da conta business → PENDING |
| 2.2 | Webhook PayPal: verificação de assinatura, `WebhookEvent`, idempotência por `(provider, external_id)`, `ProcessPaypalWebhookJob`, logs | [07](../specs/07-checkout-paypal.md) | 6 | 2.1 | ✅ | | 18/09: webhook_events, controller com verificação de assinatura, job no Sidekiq; túnel cloudflared no compose; webhook Sandbox real (refund) recebido e processado |
| 2.3 | `Client` (`find_or_create_by` email) e `Order` com estados pending/paid/failed/refunded/disputed; services `Orders::*` com lock | [07](../specs/07-checkout-paypal.md), [03](../specs/03-modelo-de-dados.md) | 6 | 2.2 | ✅ | 18/09 | Transições em 2.1/2.2, token em 2.4, `DeliverOrderJob`/email de reembolso em 2.6 |
| 2.4 | `DownloadToken`, Thank You, `GET /download/:token` com URL assinada, expiração e contagem | [08](../specs/08-entrega-download-tokens.md) | 6 | 2.3 | ✅ | 19/09 | Token, Thank You (3 estados), download com URL assinada de 5 min; validado em produção em 19/09 (S3 `launch-os-prod`, PDF real) |
| 2.5 | Recuperação de acesso (`/access/recover`) com resposta neutra, rate limit e honeypot | [08](../specs/08-entrega-download-tokens.md) | 3 | 2.4 | ✅ | 18/09 | Form de email, resposta idêntica, honeypot + tempo mínimo assinado, rate limit por IP e por hash de email; reenvio via `Delivery::ResendAccess` |
| 2.6 | ⚙️ Jobs em background (**Sidekiq**), `OrderMailer` (acesso, reenvio, reembolso) via **SES**, `MessageLog` | [09](../specs/09-notificacoes-email-whatsapp.md) | 6 | 2.4, 0.4 | ✅ | 18/09 | SES client + `:ses_api`, `OrderMailer` (3 templates), `MessageLog`, `DeliverOrderJob`/`SendOrderEmailJob`, `Delivery::*`; email no `/letter_opener` em dev e, em produção, entregue na caixa de entrada com SPF/DKIM/DMARC PASS |
| 2.7 | WhatsApp via Twilio: campo de telefone com opt-in na LP, gravação no `Client`, envio pós-webhook, callbacks de status e inbound (STOP), validação de assinatura | [09](../specs/09-notificacoes-email-whatsapp.md) | 8 | 2.6, 0.3 (Sandbox) | 🟦 | | 18/09: código completo com WebMock (client, job, webhooks, STOP, SupportMailer). Falta só o teste real no Sandbox da Twilio: Content Template `HX…` + `join`. Troca para o número real é só ENV |
| 2.8 | Admin de pedidos e clientes: listas, detalhe, reenvio por canal, regenerar/revogar token, disputas, webhook events | [11](../specs/11-admin-pedidos-clientes-dashboard.md) | 5 | 2.6, 2.7 | ✅ | 18/09 | Pedidos, clientes e webhook events completos; Sidekiq Web em `/admin/sidekiq`. Botão "Reenviar por WhatsApp" aparece quando a 2.7 ligar o Twilio |

**Total: 48 h (≈ 24 h/semana; S4 tem o feriado de 12/10)**

### 4.4 Fase 3 — Polimento do admin (a partir de 19/09, adiantado)

Decisão de 18/09: o item "polir o visual do admin" da 1.4 vira fase própria, agora que o painel tem todas as telas
reais (produtos, pedidos, clientes, webhook events). Sem spec própria; referência de estilo na spec 11.

| ID | Tarefa | Spec | Horas | Depende de | Status | Concluído em | Notas |
|---|---|---|---|---|---|---|---|
| 3.1 | Visual do admin: sidebar (responsiva, item ativo), cabeçalhos/breadcrumbs/barras de ação, tabelas (densidade, estados vazios, paginação), formulários do produto (seções, erros, arquivos, coleções), flashes e confirmações, login; helpers como fonte única de estilo; conferir no mobile | [11](../specs/11-admin-pedidos-clientes-dashboard.md) | 6 | 2.8 | ✅ | 19/09 | Referência visual Conca reimplementada em Tailwind (`adm-*`); tema claro/escuro; screenshots nos dois temas e no mobile; sem mudança de comportamento |

**Total: 6 h**

### 4.5 Fase 4 — Tracking, testes e go-live (19/10 – 25/10)

| ID | Tarefa | Spec | Horas | Depende de | Status | Concluído em | Notas |
|---|---|---|---|---|---|---|---|
| 4.1 | Meta Pixel, captura de UTMs/fbclid em cookie first-party e gravação no `Order`; ViewContent, InitiateCheckout, Purchase com `event_id`; `PageVisit` | [10](../specs/10-tracking-e-analytics.md) | 6 | 2.3 | 🟦 | | 19/09: attribution.js, Pixel via módulo (sem inline), PageVisit por beacon (LP é cacheada), consent; verificado em navegador real. Falta só o Test Events da Meta em produção |
| 4.2 | GA4, Sentry, monitor de uptime, backup diário do banco, versionamento do bucket, CSP, `config.hosts` | [10](../specs/10-tracking-e-analytics.md), [13](../specs/13-seguranca.md) | 3 | 0.5 | ⬜ | | |
| 4.3 | Dashboard básico no admin: visitas, checkouts, vendas, faturamento, conversão, vendas por campanha | [11](../specs/11-admin-pedidos-clientes-dashboard.md) | 4 | 4.1 | ⬜ | | Pode ir para Fase 6 se faltar tempo |
| 4.4 | Executar o plano de testes (T01–T27 automatizados + manuais 1–4) em Sandbox e corrigir falhas | [15](../specs/15-plano-de-testes.md) | 6 | 2.8, 4.1 | ⬜ | | |
| 4.5 | Go-live: credenciais PayPal Live, SES fora do sandbox, compra real com valor controlado + reembolso, validação no Events Manager, checklist de segurança e definição de pronto | [13](../specs/13-seguranca.md), [00](../specs/00-visao-geral.md) | 4 | 4.4 | ⬜ | | |

**Total: 23 h**

### 4.6 Trilha de conteúdo (paralela, 21/09 – 25/10) · fora das horas de dev

| ID | Tarefa | Spec | Horas | Prazo | Status | Concluído em | Notas |
|---|---|---|---|---|---|---|---|
| C.1 | Escrever o PDF (30–40 páginas) seguindo a estrutura de 3 semanas + anexos | [16](../specs/16-roadmap-e-fases.md) | 20 | S3 (11/10) | ⬜ | | Aceitar v1.0 enxuta (30 p.) se apertar |
| C.2 | Revisão do inglês (nativo ou ferramenta) | — | 4 | S3 (11/10) | ⬜ | | |
| C.3 | Diagramação do PDF e do tracker imprimível | — | 8 | S4 (18/10) | ⬜ | | |
| C.4 | Copy final da LP (headline, benefícios, FAQ, garantia) e mockup do produto | [06](../specs/06-landing-page.md) | 5 | S3 (11/10) | ⬜ | | |
| C.5 | Políticas em inglês (privacidade, termos, reembolso) revisadas | [14](../specs/14-paginas-legais.md) | 2 | S2 (04/10) | 🟦 | | Publicadas em 17/09 (1.8); falta a revisão do texto do operador (razão social) com o contador |
| C.6 | Três criativos (imagem + texto principal + headline) — ângulos dor / mecanismo / transformação | [16](../specs/16-roadmap-e-fases.md) | 6 | S5 (25/10) | ⬜ | | Subir como rascunho em 24/10 para revisão antecipada da Meta |

### 4.7 Fase 5 — Campanha de validação (26/10 – 01/11)

| ID | Tarefa | Horas | Depende de | Status | Concluído em | Notas |
|---|---|---|---|---|---|---|
| 5.1 | Criar campanha manualmente no Gerenciador: 1 campanha (vendas, otimização Purchase), 1 conjunto (Advantage+, EUA, inglês), 3 anúncios, R$ 18/dia | 2 | 4.5, C.6 | ⬜ | | |
| 5.2 | Acompanhamento diário: gasto, CTR, CPC, LP views, checkouts, vendas → planilha (seção 8 abaixo) | 3 | 5.1 | ⬜ | | |
| 5.3 | Suporte a compradores e monitoramento de erros (Sentry, MessageLog, disputas) | 2 | 5.1 | ⬜ | | |
| 5.4 | Análise final (02–03/11): comparar com referências e escolher o cenário de decisão | 4 | 5.2 | ⬜ | | |

### 4.8 Fase 6 — Pós-validação (sem datas)

Só se a análise (5.4) apontar continuidade. Ordem por impacto no próximo teste:

| Ordem | Item | Spec | Estimativa | Status |
|---|---|---|---|---|
| 1 | Correção do gargalo identificado (criativo, LP, preço, checkout ou oferta) | [16](../specs/16-roadmap-e-fases.md) | 1 semana | ⬜ |
| 2 | Conversions API com deduplicação por `event_id` (dados já gravados no `Order`) | [10](../specs/10-tracking-e-analytics.md) | 1 semana | ⬜ |
| 3 | Segundo produto na mesma aplicação (valida H5) | — | 2–3 dias + conteúdo | ⬜ |
| 4 | Cupons e Stripe como gateway alternativo | — | 1–2 semanas | ⬜ |
| 5 | Marketing API — V1 (campanha, ad set, ads em PAUSED, ativar/pausar, IDs no banco) | [16](../specs/16-roadmap-e-fases.md#meta-marketing-api-fase-2-da-plataforma) | 3 semanas + App Review | ⬜ |
| 6 | Marketing API — V2 (Insights, CAC/ROAS no dashboard, pausa automática) | idem | 1–2 semanas | ⬜ |
| 7 | Order bump, upsell, follow-up por WhatsApp com consentimento de marketing | — | 2 semanas | ⬜ |
| — | Itens cortados das fases 1–4 (dashboard 4.3) | | | ⬜ |
| — | Railway *Infrastructure as Code* (`.railway/railway.ts` + `railway config apply`) para versionar healthcheck/start command hoje definidos no dashboard | [02](../specs/02-docker-e-ambiente.md) | 1 dia | ⬜ |

O App Review da Marketing API pode ser aberto ao final da Fase 5, em paralelo aos itens 1–4.

## 5. Critérios de saída por fase

Uma fase só fecha quando todos os itens forem verificados **em produção** (ou Sandbox, onde indicado).

### Fase 1
- [ ] Login do `User` funciona; senha errada repetida bloqueia.
- [ ] Produto criado, editado e publicado somente pelo admin, sem código.
- [ ] LP renderiza todos os blocos cadastrados e passa em teste mobile (Lighthouse ≥ 85).
- [ ] Produto em rascunho retorna 404 ao público.
- [ ] `docker compose up` sobe o ambiente completo; `bundle exec rspec` verde no CI.

### Fase 2
- [ ] Compra Sandbox confirmada apenas via webhook; retorno do navegador sem webhook não libera nada.
- [ ] Preço adulterado no navegador é ignorado.
- [ ] `Client` reaproveitado em segunda compra com o mesmo email.
- [ ] Email (SES ou letter_opener em dev) e WhatsApp (Sandbox) entregues com status no `MessageLog`.
- [ ] Token expirado ou revogado nega o download com mensagem clara.
- [ ] Webhook duplicado não duplica pedido nem email.

### Fase 3
- [x] Painel consistente em todas as telas (sidebar, tabelas, formulários, flashes, login), usável no mobile; helpers como fonte única de estilo; suite verde. *(19/09; + tema escuro)*

### Fase 4
- [ ] Todos os casos T01–T27 automatizados e verdes; testes manuais 1–8 registrados em `docs/qa/`.
- [ ] ViewContent, InitiateCheckout e Purchase visíveis no Events Manager com o mesmo `event_id` do backend.
- [ ] Compra real de valor controlado paga, entregue e reembolsada com sucesso.
- [ ] Email real chega na caixa de entrada (Gmail/Outlook/iCloud) com DKIM/SPF alinhados.
- [ ] Backup do banco restaurável e Sentry recebendo erros.
- [ ] Checklist de [13-seguranca](../specs/13-seguranca.md) 100% marcado.
- [ ] Definição de pronto de [00-visao-geral](../specs/00-visao-geral.md) 100% marcada.

### Fase 5
- [ ] Sete dias completos de veiculação sem interrupção por saldo ou reprovação.
- [ ] Planilha diária preenchida (seção 8).
- [ ] Decisão registrada conforme os cenários da seção 9.

## 6. Dependências externas — checkpoint de terça-feira

Escalar se parado há mais de 5 dias.

| Dependência | Prazo típico | Necessário para | Solicitado em | Status | Aprovado em | Plano B se atrasar |
|---|---|---|---|---|---|---|
| Verificação da conta PayPal Business | dias | M2 (Live), M3 | 16/09 | 🟦 | | Conta CNPJ criada; documentos enviados, PayPal informou 2–4 dias úteis (até ~22/09). Live no Developer bloqueado até lá. Fase 2 inteira em Sandbox; go-live aguarda |
| Verificação do domínio + revisão da conta de anúncios Meta | horas a dias | M4 | 16/09 | ✅ | 16/09 | Domínio verificado por TXT no mesmo dia; conta de anúncios já ativa com pagamento |
| WhatsApp Sender aprovado (Meta via Twilio) | dias a semanas | 2.7 em produção | — | ⏸ | | **Não solicitado** (decisão 16/09: adiar upgrade Twilio). Lançar só com email (`TWILIO_ENABLED=false`); se solicitar até 04/10 ainda há chance de aprovar antes do go-live |
| Template `order_delivery` aprovado | horas a dias | 2.7 em produção | — | ⏸ | | Depende do Sender; testar no Sandbox com template próprio |
| SES fora do sandbox + DKIM/SPF/DMARC verificados | até 24 h + propagação DNS | M1, 2.6 | 16/09 | ✅ | 16/09 | DKIM e MAIL FROM *verified*; acesso à produção aprovado no mesmo dia (cota 50.000/dia, 14/s); DMARC `p=quarantine` publicado após teste PASS no Gmail |
| Propagação do CNAME `www` e do redirect do apex (HostGator) + certificado do Railway | horas | M1 | 16/09 | ✅ | 16/09 | `https://www.devbatista.online/up` → 200; apex 301 → www |
| Revisão dos três anúncios pela Meta | horas a 1 dia | M4 | | ⬜ | | Subir criativos em 24/10 como rascunho |

## 7. Riscos de prazo

| Risco | Prob. | Impacto | Mitigação | Status |
|---|---|---|---|---|
| Aprovações externas atrasam (PayPal, WhatsApp, Meta, SES) | Alta | M3/M4 deslizam | Fase 0 disparada na S0; plano B por dependência (seção 6) | 🟦 monitorando |
| Capacidade real abaixo de 25 h/semana | Média | +1 semana | Cortar primeiro o que não bloqueia a campanha: dashboard (4.3) e polimento do admin (3.1) → Fase 6 | ⬜ |
| Conteúdo do PDF não fica pronto até 18/10 | Média | M3 bloqueado | Começar na S1; aceitar v1.0 enxuta (30 p.) | ⬜ |
| Template da LP consome mais que 10 h | Média | M1 desliza | Componentes prontos (Tailwind), um único template; refinar na Fase 6 | ✅ Não ocorreu: 1.6 entregue em 17/09 |
| Bugs no webhook descobertos no go-live | Baixa | M3 desliza dias | Plano de testes completo na 4.4; compra real com reembolso na 4.5 | ⬜ |
| Escopo cresce durante a execução | Alta | Todas as fases | Item novo → Fase 6; revisar a lista "fora do MVP" na sexta | 🟦 monitorando |
| Configuração de webhooks em dev (túnel HTTPS) consome tempo | Média | 2.2 desliza | Cloudflared/ngrok como serviço do compose desde 1.1 | ⬜ |

## 8. Campanha — acompanhamento diário (Fase 5)

Referências: CTR > 1% · CPC < US$ 1.50 · LP Views/cliques > 70% · InitiateCheckout/LP Views > 3% · Purchase ≥ 1.

| Dia | Data | Gasto (R$) | Impressões | Cliques | CTR | CPC (US$) | LP Views | Checkouts | Vendas | Obs. |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 26/10 | | | | | | | | | |
| 2 | 27/10 | | | | | | | | | |
| 3 | 28/10 | | | | | | | | | |
| 4 | 29/10 | | | | | | | | | |
| 5 | 30/10 | | | | | | | | | |
| 6 | 31/10 | | | | | | | | | |
| 7 | 01/11 | | | | | | | | | |
| **Total** | | | | | | | | | | |

## 9. Decisão ao final da campanha (preencher em 03/11)

| Cenário | Leitura | Próximo passo | Escolhido? |
|---|---|---|---|
| CTR baixo e poucos cliques | Criativo/ângulo não prende atenção | Trocar criativos e ângulos; manter LP | ⬜ |
| CTR bom, poucos InitiateCheckout | LP não converte interesse em intenção | Revisar headline, prova, preço e CTA | ⬜ |
| Muitos InitiateCheckout, nenhuma venda | Atrito no checkout ou no preço | Testar PayPal em mobile, reduzir passos, testar preço | ⬜ |
| Uma ou mais vendas | Sinal de demanda (não prova de lucro) | Repetir com R$ 250 mantendo a estrutura | ⬜ |

**Decisão registrada:** _(cenário, justificativa, próximo orçamento ou encerramento)_

## 10. Revisões semanais (sexta-feira)

Template por semana: tarefas concluídas · horas reais vs. planejadas · horas restantes da fase · marco viável? · bloqueios · ajustes.

### S0 — 14 a 20/09
- Concluídas:
- Horas: — (sem dev)
- Aprovações solicitadas:
- Marco M0 viável?
- Bloqueios:
- Ajustes:

### S1 — 21 a 27/09
- Concluídas:
- Horas reais / planejadas:
- Restante da Fase 1:
- Marco M1 viável?
- Bloqueios:
- Ajustes:

### S2 — 28/09 a 04/10
-

### S3 — 05 a 11/10
-

### S4 — 12 a 18/10 (feriado 12/10)
-

### S5 — 19 a 25/10
-

### S6 — 26/10 a 01/11
-

### S7 — 02 a 08/11 (feriado 02/11)
-

## 11. Registro de decisões

| Data | Decisão | Motivo | Impacto |
|---|---|---|---|
| 2026-09-15 | Specs técnicas escritas em `docs/specs/` a partir do documento MVP v2.0 | Preparar o desenvolvimento | Cada tarefa deste cronograma referencia uma spec |
| 2026-09-15 | Ambiente **100% Docker** (dev, teste, produção); Rails **8.1.3**; PostgreSQL 17 | Definição do projeto | Tarefa 1.1 inclui Dockerfile/compose; hospedagem por container |
| 2026-09-16 | Jobs com **Sidekiq + Redis** em vez de Solid Queue | Preferência do projeto | Tarefa 2.6; serviço `redis` + `sidekiq` no compose; Redis gerenciado em produção |
| 2026-09-16 | Frontend **sem Hotwire/Turbo/Stimulus**: ERB + JS puro via importmap | Preferência do projeto | Tarefas 1.4, 1.6, 2.1 usam módulos JS com `data-module`; sem Node |
| 2026-09-16 | Email: **Amazon SES** em produção, `letter_opener_web` em dev (transporte revisto para API na decisão abaixo) | Preferência do projeto | Tarefa 0.4 inclui setup do SES e saída do sandbox; Mailpit removido |
| 2026-09-16 | Testes com **RSpec + FactoryBot** em vez de Minitest | Preferência do projeto | Tarefa 1.1 inclui `rspec:install`; plano de testes mapeado para `spec/` |
| 2026-09-16 | Autenticação do admin com o **gerador nativo do Rails 8** (`rails g authentication`), sem Devise | Um único `User`, sem cadastro público nem recuperação por email; menos dependências | Tarefa 1.2; lockout e rate limit implementados à mão conforme spec 04 |
| 2026-09-16 | Provedores externos (PayPal, SES, Twilio) como **services em `app/services/providers/` com integração via API oficial**; email pela API do SES (não SMTP); **sem gems de SDK** (PayPal e Twilio via Faraday; única exceção `aws-sdk-sesv2`) | Fronteira única e testável com o mundo externo; erros tipados para retry; `MessageId` do SES gravado no `MessageLog` | Tarefas 2.1, 2.6, 2.7; ENVs `SES_*` de API; casos de teste T28–T30 |
| 2026-09-16 | Hospedagem: **Railway** (deploy por Dockerfile, serviços `launch_os` + `sidekiq`, plugins Postgres e Redis); projeto gerado com `--skip-kamal` | Domínio já existe; plataforma escolhida pelo projeto | Tarefas 0.4 e 1.1; entrypoint lê `PORT` |
| 2026-09-16 | Rails travado em `~> 8.1.3` (lock em **8.1.3.1**, patch de segurança sobre a 8.1.3) | Patch level só corrige CVEs; manter exato em 8.1.3 deixaria a app vulnerável | Nenhum; `bundle update rails --conservative` quando sair novo patch |
| 2026-09-16 | Imagens do MinIO via **quay.io** (`quay.io/minio/minio`, `quay.io/minio/mc`) | MinIO removeu as imagens do Docker Hub | compose.yml |
| 2026-09-16 | **DNS permanece na HostGator** (domínio na Namecheap); sem migração para Cloudflare. App em **`www.devbatista.online`**, apex com redirect 301 no cPanel; MAIL FROM do SES em `ses.devbatista.online` para não tocar o email da HostGator | Railway exige CNAME e a HostGator não faz CNAME no apex; usuário optou por não alterar o registro | Todas as URLs públicas usam `www`; `APP_HOST`; `config.hosts`; specs 00/01/02/05/06/07/09/13/16 |
| 2026-09-16 | Chave primária **`id uuid`** em todas as tabelas | Ids não sequenciais em URLs e nos identificadores enviados ao PayPal | Initializer de generators antes da 1ª migration (tarefa 1.1); `implicit_order_column = created_at`; FKs uuid |
| 2026-09-16 | **WhatsApp Sender adiado**: Twilio fica em trial/Sandbox (subconta `launch_os`); upgrade (US$ 20 pré-pagos) e pedido do Sender só se decidido até 04/10 | Evitar custo antes de validar; Sandbox cobre todo o desenvolvimento da 2.7 | Go-live pode sair com `TWILIO_ENABLED=false` (só email); dependência da seção 6 marcada ⏸ |
| 2026-09-17 | **Railway configurado pelo dashboard, sem `railway.json`**: healthcheck `/up` do web e start command do `sidekiq` definidos em Settings → Deploy; arquivos de Config as Code removidos | O Railway descontinuou o Config as Code (válido só até 01/12/2026; serviços criados após 28/08/2026 não aderem — o `sidekiq` ignorava o `railway.sidekiq.json`). O substituto (`.railway/railway.ts` + `railway config apply`) exige CLI novo e TypeScript; não vale antes do MVP | Spec 02 e README atualizados; IaC do Railway registrado como item da Fase 5 |
| | | | |
