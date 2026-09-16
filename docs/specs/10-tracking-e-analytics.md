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

Na LP, `RecordPageVisitJob.perform_later(product_id, attrs)` — não bloqueia a resposta. Registra
`path`, UTMs, `fbclid`, `referrer`, `user_agent`, `visitor_id`, `ip_hash`. Ignorar bots conhecidos
(user agent com `bot|crawler|spider|facebookexternalhit`).

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
Os snippets base do Pixel e do GA4 são inline no `<head>` com nonce da CSP, renderizados apenas quando
os IDs estão configurados e `@preview` é falso.

## GA4

`gtag.js` com `GA4_MEASUREMENT_ID`. Eventos e-commerce padrão:
`view_item`, `begin_checkout`, `purchase` (`transaction_id: order.id`, `value`, `currency`, `items`).
Mesma regra de disparo único para `purchase`.

## Consentimento de cookies

Banner simples ("We use cookies and pixels to measure our ads. [OK] [Privacy Policy]"). Não bloqueia
o Pixel para tráfego dos EUA no MVP (não há exigência tipo GDPR), mas o banner e a Privacy Policy
DEVEM informar o uso. Preferência gravada em cookie `lo_consent`.

## Validação

- Meta Events Manager → *Test Events* com o código de teste na LP para verificar `ViewContent`, `InitiateCheckout` e `Purchase`.
- Domínio verificado no Business Manager e eventos priorizados (Aggregated Event Measurement) com `Purchase` no topo.
- GA4 DebugView.

## Critérios de aceite

- [ ] Visita `/:slug?utm_source=ig&utm_campaign=test&fbclid=abc` → após compra, `Order` tem esses campos preenchidos.
- [ ] Segunda visita sem UTMs no mesmo navegador mantém a atribuição original (first-touch).
- [ ] `ViewContent`, `InitiateCheckout` e `Purchase` aparecem no Test Events da Meta com `value`/`currency` corretos.
- [ ] Recarregar a Thank You não dispara um segundo `Purchase`.
- [ ] Preview do admin não carrega Pixel nem GA4.
- [ ] `PageVisit` gravado de forma assíncrona; LP responde sem esperar o job.
