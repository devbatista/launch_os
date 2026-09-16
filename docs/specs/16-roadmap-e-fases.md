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

## Fase 3 — Tracking, testes e go-live (3–5 dias)

| # | Tarefa | Spec |
|---|---|---|
| 3.1 | Captura de atribuição (cookie + Order), `PageVisit` assíncrono | 10 |
| 3.2 | Meta Pixel (PageView, ViewContent, InitiateCheckout, Purchase com `event_id`), GA4, banner de cookies | 10 |
| 3.3 | Dashboard admin | 11 |
| 3.4 | Sentry, uptime monitor, backups, CSP, `config.hosts`, checklist de segurança | 13 |
| 3.5 | Suite de testes T01–T27 verde; testes manuais 1–8 | 15 |
| 3.6 | Deploy produção (container), DNS Cloudflare, HTTPS, credenciais Live | 02 |
| 3.7 | Compra real de US$ 14.90 + reembolso; validar Events Manager | 15 |
| 3.8 | Publicar produto; **Definição de pronto** 100% marcada | 00 |

## Fase 4 — Campanha de validação (1 semana + 2 dias de análise)

- 1 campanha de vendas (otimizada para Purchase), 1 conjunto amplo (Advantage+), 3 criativos
  (ângulos: dor / mecanismo / transformação), EUA, inglês, ~R$ 18/dia × 7 dias.
- Campanhas criadas **manualmente** no Gerenciador de Anúncios no MVP.
- Expectativa realista: US$ 20–25 ≈ 15–50 cliques ≈ 0–2 vendas. O teste mede CTR, CPC e comportamento na LP;
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
| Médio prazo | Order bump, upsell na Thank You, bundles, A/B de headline/preço, watermark no PDF, follow-up por WhatsApp com consentimento de marketing, **Meta Marketing API** (abaixo) |
| Longo prazo | Múltiplas marcas/domínios, área do comprador, lista de email e automações, novos mercados/idiomas |

### Meta Marketing API (fase 2 da plataforma)

Só implementar quando houver ≥ 2 produtos ativos ou campanhas semanais recorrentes.

Regra inegociável: **todo objeto criado via API nasce `PAUSED`**; ativação é ação explícita do `User` no admin.

- Pré-requisitos: app Business na Meta for Developers, permissões `ads_management`, `ads_read`,
  `business_management` (App Review com vídeo), token de System User de longa duração, gem `koala` ou
  Faraday com versão da Graph API fixada, Pixel com `Purchase` validado.
- V1: criar Campaign (`OUTCOME_SALES`) → AdSet (`daily_budget`, `US`, `OFFSITE_CONVERSIONS` + `promoted_object` com `pixel_id`/`PURCHASE`) → upload de imagens → AdCreatives (LP com UTMs) → Ads (3), tudo PAUSED; botões ativar/pausar; IDs da Meta gravados imediatamente após cada resposta (criação parcial fica visível para corrigir/arquivar).
- V2: Insights API (gasto, cliques, CTR, CPC, compras) → CAC/ROAS no dashboard com `Orders` como verdade; pausa automática por orçamento/data; vídeo; múltiplos conjuntos; status de revisão.
- Modelo adicional: `AdAccount`, `Campaign`, `AdSet`, `AdCreative`, `Ad`, `CampaignInsight`.
- Riscos: App Review lento/recusado, rate limits e versionamento da API, erros gastam dinheiro real (daí PAUSED), atribuição da Meta ≠ pedidos reais.

## Critérios de aceite do roadmap

- [ ] Cada tarefa das fases 1–3 vira uma issue/ticket com link para a spec correspondente.
- [ ] Nenhum item de "Pós-validação" é iniciado antes da Fase 4 terminar.
