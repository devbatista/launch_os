# 16 — Roadmap e fases

Estimativas para um desenvolvedor em dedicação parcial. Produção do PDF e dos criativos ocorre em
paralelo às fases 1 e 2. **Solicitar o sender e o template de WhatsApp na Fase 1** (aprovação pela
Meta leva dias) e criar a conta de anúncios com antecedência (revisão de conta nova).

## Fase 1 — Base (1–2 semanas)

| # | Tarefa | Spec | Entregável |
|---|---|---|---|
| 1.1 | Projeto Rails 8.1.3 (`--skip-solid --skip-hotwire --skip-test`), RSpec + FactoryBot + WebMock configurados, Sidekiq + Redis, importmap com entries `landing.js`/`application.js` e loader por `data-module`, Docker (dev + prod), compose com db/redis/sidekiq/minio, `letter_opener_web`, CI | 01, 02 | `docker compose up` funcional, job de teste processado |
| 1.2 | `User` + autenticação admin, lockout, rate limit, layout do admin | 04 | login/logout |
| 1.3 | Migrations completas (todas as tabelas), modelos, validações, seeds | 03 | `db:migrate` + testes de modelo |
| 1.4 | CRUD de `Product` + Benefit/Testimonial/Faq + uploads Active Storage (MinIO) + publish/unpublish/archive | 05 | admin de produtos |
| 1.5 | Template `direct_response`, rota `/:slug`, preview de rascunho, SEO, imagens WebP | 06 | LP visível |
| 1.6 | Páginas legais + rodapé + email de suporte | 14 | `/privacy`, `/terms`, `/refund-policy` |
| 1.7 | Cadastrar manualmente o *21-Day Procrastination Reset* (draft) | — | produto no admin |
| 1.8 | Abrir solicitações externas: PayPal Business + app Sandbox/Live, Twilio sender + template, **SES: identidade de domínio + pedido de saída do sandbox**, Meta Business + conta de anúncios + verificação de domínio | 07, 09, 10 | credenciais em `.env` |

## Fase 2 — Pagamento e entrega (2 semanas)

| # | Tarefa | Spec |
|---|---|---|
| 2.1 | `Providers::Paypal::Client` (OAuth cache, create, capture, get, verify signature) com WebMock | 07 |
| 2.2 | `POST /checkout/paypal` + `capture`; `modules/checkout.js` (JS puro) com PayPal JS SDK na LP; campo telefone + opt-in | 06, 07 |
| 2.3 | `Webhooks::PaypalController`, `WebhookEvent`, `ProcessPaypalWebhookJob` | 07 |
| 2.4 | Services `Orders::MarkPaid / MarkFailed / MarkRefunded / MarkDisputed` com lock e idempotência; `Client` find_or_create | 07, 03 |
| 2.5 | `DownloadToken`, Thank You, `/download/:token` com URL assinada, `/access/recover` | 08 |
| 2.6 | `Providers::Ses::Client` + delivery method `:ses_api`, `OrderMailer` (delivery, access_resend, refund_confirmation), domínio autenticado (Easy DKIM, MAIL FROM/SPF, DMARC, fora do sandbox), `SendAccessEmailJob`, `MessageLog` | 09 |
| 2.7 | `Providers::Twilio::Client` (REST API via Faraday), `SendWhatsappMessageJob`, template Utility, callbacks de status e inbound (STOP), validação de assinatura HMAC; testar no Sandbox da Twilio | 09 |
| 2.8 | Admin: pedidos (index/show, reenvio, regenerar/revogar token, disputa), clientes, webhook events | 11 |
| 2.9 | Compra Sandbox ponta a ponta via túnel HTTPS | 15 |

## Fase 3 — Polimento do admin (~6 h, adiantada para 19/09)

Decisão de 18/09: o item "polir o visual do admin" da tarefa 1.4 vira fase própria, executada assim que o painel tem
todas as telas reais (produtos, pedidos, clientes, webhook events — Fase 2). As fases seguintes foram renumeradas;
datas e marcos M1–M5 não mudaram.

| # | Tarefa | Spec |
|---|---|---|
| 3.1 | Visual do admin: sidebar responsiva, cabeçalhos/breadcrumbs/ações, tabelas e estados vazios, formulários do produto, flashes/confirmações, login; helpers de estilo como fonte única; conferência no mobile | 11 |

## Fase 4 — Tracking, testes e go-live (3–5 dias)

| # | Tarefa | Spec |
|---|---|---|
| 4.1 | Captura de atribuição (cookie + Order), `PageVisit` assíncrono | 10 |
| 4.2 | Meta Pixel (PageView, ViewContent, InitiateCheckout, Purchase com `event_id`), GA4, banner de cookies | 10 |
| 4.3 | Dashboard admin | 11 |
| 4.4 | Sentry, uptime monitor, backups, CSP, `config.hosts`, checklist de segurança | 13 |
| 4.5 | Suite de testes T01–T27 verde; testes manuais 1–8 | 15 |
| 4.6 | Deploy produção (Railway), CNAME `www` na HostGator + redirect do apex, HTTPS, credenciais Live | 02 |
| 4.7 | Compra real de US$ 14.90 + reembolso; validar Events Manager | 15 |
| 4.8 | Publicar produto; **Definição de pronto** 100% marcada | 00 |

## Fase 5 — Campanha de validação (1 semana + 2 dias de análise)

- 1 campanha de vendas (otimizada para Purchase), 1 conjunto amplo (Advantage+), 3 criativos
  (ângulos: dor / mecanismo / transformação), EUA, inglês, ~R$ 28/dia × 7 dias (decisão 02/10; o plano
  original era R$ 18/dia).
- Campanhas criadas **manualmente** no Gerenciador de Anúncios no MVP.
- Expectativa realista: US$ 35–40 ≈ 25–80 cliques ≈ 0–2 vendas. O teste mede CTR, CPC e comportamento na LP;
  venda é bônus.

Métricas e referências: CTR > 1% · CPC < US$ 1.50 · LP Views/cliques > 70% · InitiateCheckout/LP Views > 3% · Purchase ≥ 1.

Decisão ao fim dos 7 dias:

| Cenário | Leitura | Próximo passo |
|---|---|---|
| CTR baixo, poucos cliques | criativo/ângulo | trocar criativos; manter LP |
| CTR bom, poucos InitiateCheckout | LP não converte | revisar headline, prova, preço, CTA |
| Muitos InitiateCheckout, 0 vendas | atrito no checkout/preço | testar PayPal mobile, reduzir passos, testar preço |
| ≥ 1 venda | demanda (não lucro) | repetir com R$ 250 mantendo estrutura |

Progressão de investimento: R$ 130 → 250 → 500 → 1.000, sempre corrigindo o gargalo antes de escalar.

## Pós-validação (não entra no MVP)

| Horizonte | Itens |
|---|---|
| Curto prazo | Conversions API (reutiliza `event_id`, `fbp`, `fbc`, IP, UA já gravados), novos templates de LP, cupons, segundo produto, Stripe |
| Médio prazo | Order bump, upsell na Thank You, bundles, A/B de headline/preço, watermark no PDF, follow-up por WhatsApp com consentimento de marketing, **Meta Marketing API** (abaixo; Insights antecipado em 05/10) |
| Longo prazo | Múltiplas marcas/domínios, área do comprador, lista de email e automações, novos mercados/idiomas |

### Meta Marketing API (fase 2 da plataforma)

**Decisão 05/10:** a ordem foi invertida e o **Insights (só leitura) foi antecipado**, durante a Fase 5,
por pedido do usuário — exceção registrada ao critério "nenhum item de pós-validação antes da Fase 5
terminar". A criação de campanhas continua condicionada a ≥ 2 produtos ativos ou campanhas semanais
recorrentes, e nada que **escreva** na conta de anúncios vai para produção antes de M5.

Regra inegociável: **todo objeto criado via API nasce `PAUSED`**; ativação é ação explícita do `User` no admin.

Premissas conferidas na documentação da Meta em 05/10:

- **Sem App Review para conta própria**: *"If your app is only managing your ad account, standard access
  to the `ads_read` and `ads_management` permissions are sufficient."* O nível Limited da Marketing API
  tem rate limit agressivo por conta — suficiente para dezenas de chamadas por semana.
- **Graph API v26.0** (29/07/2026), fixada em `META_GRAPH_VERSION`; subir junto com o changelog.
- **Faraday, sem SDK** (`koala` descartada — regra dos provedores, spec 01).
- **Advantage+ unificado** (v25+): as APIs legadas de ASC foram descontinuadas; uma campanha de vendas
  vira `ADVANTAGE_PLUS_SALES` com orçamento de campanha + público Advantage+ + posicionamentos
  automáticos — a mesma estrutura da campanha manual da Fase 5. Conferir o `advantage_state` ao criar.

Pré-requisitos (fora do código): app Business na Meta for Developers ligado ao portfólio `DevBatista`;
System User com acesso à conta de anúncios, ao Pixel e à Página; token de longa duração com `ads_read`
(Insights) e, depois, `ads_management` (criação). *05/10: o app `Launch OS` foi criado com o caso de uso
"Criar e gerenciar anúncios com a API de Marketing", vinculado ao portfólio `DevBatista` (id
106724254821671), que **já é verificado** — por isso nenhum requisito pendente. Nível de acesso: Limited
(subir exige app publicado + App Review; não necessário). "Atualização automática de versão" ligada: rede de
segurança se a v26.0 for descontinuada; reavaliar antes da criação de campanhas (escrita). Não reaproveitar
o app CatalystOps: rate limit é por app.*

#### Insights — implementado (05/10)

- `Providers::Meta::Client#ad_insights(since:, until_date:)`: `GET /act_{id}/insights` com `level=ad`,
  `time_increment=1`, `use_account_attribution_setting=true`, campos `ad_id, ad_name, campaign_id,
  campaign_name, date_start, spend, account_currency, impressions, inline_link_clicks, actions`; segue
  `paging.next`. Erros: 4, 17, 613, 80000, 80004, `is_transient`, 429 e 5xx → `TransientError`;
  190/10/200/100 → `ApiError` (permanente).
- `AdInsight` (`ad_insights`): uma linha por (`meta_ad_id`, `date`), upsert a cada sync. Ações do Pixel:
  `landing_page_view`, `offsite_conversion.fb_pixel_initiate_checkout`, `offsite_conversion.fb_pixel_purchase`
  (não as `omni_*`, que somam outros canais). Gasto em centavos da moeda da conta (BRL).
- `MetaAds::SyncInsights` regrava os **últimos 7 dias** a cada execução: a Meta ainda atribui conversões
  a dias passados (7 dias após o clique) e só congela os números após 28 dias.
- `SyncAdInsightsJob` a cada 6 h via **sidekiq-cron** (`config/schedule.yml`; aba Cron em `/admin/sidekiq`).
  No-op sem `META_ACCESS_TOKEN`/`META_AD_ACCOUNT_ID`. Backfill: `SyncAdInsightsJob.perform_later("2026-10-02")`.
- Dashboard (spec 11): gasto, CTR de link, vendas da Meta (`Order` pago com `utm_source=facebook`), CAC,
  ROAS líquido (`paypal_receivable_cents` ÷ gasto, ambos em BRL — sem câmbio próprio) e tabela por anúncio
  (`ad_name` = `utm_content`). **Pedidos são a verdade**; compras reportadas pela Meta aparecem só como referência.

#### Gasto por produto — implementado (05/10)

- `AdCampaign` (`ad_campaigns`: `meta_campaign_id`, `name`, `product_id` opcional): o sync cria a campanha
  sem produto e depois só atualiza o nome (`upsert_all … update_only: name`) — nunca desfaz o vínculo.
- Vínculo **manual por campanha** em `/admin/ad_campaigns` (estrutura atual: 1 campanha = 1 produto).
  Descartados: automático pela URL do criativo (frágil com Advantage+/`asset_feed_spec`, erro silencioso) e
  manual por anúncio (classificação a cada anúncio novo).
- A migration preenche as campanhas já vistas em `ad_insights`, sem produto — vincular no admin após o deploy.

#### Criação — próxima etapa (após M5)

- Criar Campaign (`OUTCOME_SALES`, orçamento de campanha) → AdSet (`US`, público Advantage+,
  `OFFSITE_CONVERSIONS` + `promoted_object` com `pixel_id`/`PURCHASE`) → upload de imagens → AdCreatives
  (LP com `url_tags` das UTMs) → Ads, tudo `PAUSED`; ids da Meta gravados logo após cada resposta e passo
  com id já gravado é pulado no retry (publicação retomável, sem duplicar); botões ativar/pausar com
  confirmação do orçamento. *Nomes exatos de campos a conferir na doc da v26 antes de codar; 9:16 por
  posicionamento (`asset_feed_spec`) pode ficar fora da primeira versão.*
- Proteções obrigatórias: teto `META_MAX_DAILY_BUDGET_CENTS` validado no model **e** no service antes da
  chamada (orçamento vai em centavos — erro de unidade gasta 100×), data de término obrigatória, interruptor
  `META_ADS_ENABLED`.
- Modelo enxuto: `ad_campaigns` (já existe com o vínculo ao produto; ganha conjunto e orçamento, 1:1 na
  estrutura atual) e `ads`; conta e Pixel por ENV. Campanha criada pelo sistema já nasce com o produto.
- Depois: pausa automática por orçamento/data, vídeo, múltiplos conjuntos, status de revisão.
- Riscos: rate limits e versionamento da API, erros gastam dinheiro real (daí PAUSED + teto), atribuição da
  Meta ≠ pedidos reais.

## Critérios de aceite do roadmap

- [ ] Cada tarefa das fases 1–3 vira uma issue/ticket com link para a spec correspondente.
- [ ] Nenhum item de "Pós-validação" é iniciado antes da Fase 5 terminar.
