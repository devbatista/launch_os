# 10 — Tracking e dados de marketing

Objetivo: cada visita e cada pedido preservam a origem da campanha, e os eventos da Meta refletem a
realidade do backend (`Purchase` só após confirmação).

## Captura de atribuição

Parâmetros capturados na **primeira visita** e mantidos em cookie first-party:

`utm_source, utm_medium, utm_campaign, utm_content, utm_term, fbclid, referrer, landing_path`

Implementação (duas camadas, para que o cache da LP não perca dados):

1. **Cliente** — `modules/attribution.js` (JS puro, ativado por `<body data-module="attribution">` na LP):
   lê `location.search`, grava cookie `lo_attr` (JSON, 30 dias, `SameSite=Lax`, `Secure`) se ainda não
   existir (first-touch). `_fbp`/`_fbc` são cookies do próprio Pixel e são lidos no servidor no checkout.
2. **Servidor** — `POST /checkout/paypal` lê `cookies[:lo_attr]` (+ `_fbp`, `_fbc`) e copia para o `Order`
   na criação. Fallback: se o cookie não existir, usa os params da própria requisição.

A atribuição sobrevive ao redirecionamento ao PayPal porque já está no `Order` antes de sair da página.

`visitor_id`: cookie `lo_vid` (UUID, 1 ano) para contagem de visitantes únicos no `PageVisit`.

## PageVisit (analytics interno)

**Decisão (19/09, tarefa 4.1):** a visita é contada por um **beacon** — `modules/attribution.js` faz
`navigator.sendBeacon("/visits", JSON)` ao carregar a LP — e não pelo `LandingPagesController`: a LP é
`Cache-Control: public` e o Thruster serve a maioria dos acessos do cache, sem passar pelo Rails.
`VisitsController#create` (sem CSRF, rate limit 60/min por IP, 204 sempre) descarta bots, calcula o
`ip_hash` e chama `RecordPageVisitJob.perform_later(attrs)`. Registra `path`, UTMs, `fbclid`, `referrer`,
`user_agent`, `visitor_id` (cookie `lo_vid`), `ip_hash` (SHA-256 de `secret_key_base:data:ip` — muda por
dia, nunca guarda o IP). Bots: user agent com `bot|crawler|spider|facebookexternalhit|headless|lighthouse`
(checado no controller e no job). Efeito colateral bom: quem não roda JS (a maioria dos bots) não conta.
Cada visita leva os parâmetros da URL atual (o first-touch fica no cookie `lo_attr` e vai para o `Order`).

Alimenta o dashboard (visitas, visitantes únicos, conversão). Não substitui GA4/Meta.

## Meta Pixel

Carregado apenas quando `META_PIXEL_ID` está definido e `@preview` é falso.

| Evento | Onde | Parâmetros |
|---|---|---|
| `PageView` | toda LP | automático |
| `ViewContent` | LP do produto (`show`) | `content_ids: [product.id]`, `content_name`, `content_type: "product"`, `value`, `currency` |
| `InitiateCheckout` | clique no botão PayPal (`onClick` do SDK) — `modules/tracking.js` exporta `initiateCheckout(data)` chamado por `checkout.js` | `content_ids`, `value`, `currency` |
| `Purchase` | Thank You, **primeira visita apenas** | `value`, `currency`, `content_ids`, `eventID: order.event_id` |

`Purchase` é renderizado pelo servidor só quando `order.paid? && order.purchase_tracked_at.nil?`; o
controller marca `purchase_tracked_at` na mesma requisição. O `eventID` = `order.event_id` (UUID)
prepara a deduplicação com a Conversions API (fase 2), que usará o mesmo id server-side.

Desde já: guardar `fbp`, `fbc`, `ip_address`, `user_agent` no `Order` (dados necessários para a CAPI).

`modules/tracking.js` é um wrapper fino: `viewContent(data)`, `initiateCheckout(data)`, `purchase(data)`
chamam `window.fbq` e `window.gtag` **se existirem** (no-op quando Pixel/GA4 não estão carregados ou em preview).

**Decisão (19/09):** o Pixel **não** usa snippet inline — o layout `landing` declara
`<body data-module="tracking" data-pixel-id="…">` (só com `META_PIXEL_ID` e fora do preview) e o próprio
`tracking.js` cria o stub `fbq` (fila até o `fbevents.js` carregar), injeta o script, faz `init` + `PageView`.
Zero inline = nada a liberar na CSP além de `connect.facebook.net` (4.2). Dados dos eventos vão em `data-*`:
a LP tem `<main data-module="attribution tracking" data-event="view_content" data-product-id data-product-name
data-value data-currency>`, o `#buy` os mesmos `data-*` (o `checkout.js` os passa ao `initiateCheckout` no
`onClick` do SDK) e a Thank You `data-event="purchase" data-event-id data-order-id …`. O GA4 (`gtag`) segue o
mesmo caminho na 4.2.

## GA4

`gtag.js` com `GA4_MEASUREMENT_ID`. Eventos e-commerce padrão:
`view_item`, `begin_checkout`, `purchase` (`transaction_id: order.id`, `value`, `currency`, `items`).
Mesma regra de disparo único para `purchase`.

*(4.2, 20/09: mesmo caminho do Pixel — `<body data-module="tracking" data-ga4-id="…">` só com
`GA4_MEASUREMENT_ID` e fora do preview; `tracking.js` cria `dataLayer`/`gtag`, injeta o `gtag/js` e faz
`config`. `page_view` sai no `config`; os três eventos de e-commerce já eram disparados pelos wrappers.
Sem GA4 em produção por enquanto — a variável fica vazia até existir uma propriedade.)*

## Consentimento de cookies

Banner simples ("We use cookies and pixels to measure our ads. [OK] [Privacy Policy]"). Não bloqueia
o Pixel para tráfego dos EUA no MVP (não há exigência tipo GDPR), mas o banner e a Privacy Policy
DEVEM informar o uso. Preferência gravada em cookie `lo_consent` (1 ano). *(4.1: `shared/_consent_banner`
+ `modules/consent.js`; fora do preview.)*

## Validação

- Meta Events Manager → *Test Events* com o código de teste na LP para verificar `ViewContent`, `InitiateCheckout` e `Purchase`.
- Domínio verificado no Business Manager e eventos priorizados (Aggregated Event Measurement) com `Purchase` no topo.
- GA4 DebugView.

## Critérios de aceite

- [x] Visita `/:slug?utm_source=ig&utm_campaign=test&fbclid=abc` → após compra, `Order` tem esses campos preenchidos. *(T22 no checkout desde a 2.1; cookie `lo_attr` verificado em navegador real na 4.1)*
- [x] Segunda visita sem UTMs no mesmo navegador mantém a atribuição original (first-touch). *(4.1: verificado com Chromium — `lo_attr` intacto; a `PageVisit` da 2ª visita vem sem UTMs, como deve)*
- [x] `ViewContent`, `InitiateCheckout` e `Purchase` aparecem no Test Events da Meta com `value`/`currency` corretos. *(19/09, em produção, conjunto `LaunchOS`: os três recebidos e processados; `Purchase` com a identificação do evento = `order.event_id`)*
- [x] Recarregar a Thank You não dispara um segundo `Purchase`. *(T21 desde a 2.4)*
- [x] Preview do admin não carrega Pixel nem GA4. *(4.1: request spec — sem `data-pixel-id`, atribuição nem aviso no preview)*
- [x] `PageVisit` gravado de forma assíncrona; LP responde sem esperar o job. *(4.1: beacon → job; LP nem vê a requisição)*
