// Eventos de marketing (spec 10): PageView, ViewContent, InitiateCheckout, Purchase no Meta Pixel e
// page_view, view_item, begin_checkout, purchase no GA4. Pixel e gtag.js são carregados aqui, sem
// snippet inline: o layout declara <body data-module="tracking" data-pixel-id="…" data-ga4-id="…">
// só com META_PIXEL_ID / GA4_MEASUREMENT_ID e fora do preview.
//
//   <main data-module="tracking" data-event="view_content" data-product-id data-product-name data-value data-currency>
//   <section data-module="tracking" data-event="purchase" data-event-id data-order-id data-product-id data-value data-currency>
const PIXEL_SRC = "https://connect.facebook.net/en_US/fbevents.js";
const GTAG_SRC = "https://www.googletagmanager.com/gtag/js";

function debug(name, data) {
  if (window.__lo_tracking_debug) console.debug("[tracking]", name, data);
}

// Stub oficial do Pixel em forma de módulo: enfileira chamadas até o fbevents.js carregar.
function loadPixel(pixelId) {
  if (window.fbq) return;
  const fbq = function () {
    fbq.callMethod ? fbq.callMethod.apply(fbq, arguments) : fbq.queue.push(arguments);
  };
  fbq.push = fbq;
  fbq.loaded = true;
  fbq.version = "2.0";
  fbq.queue = [];
  window.fbq = fbq;
  window._fbq = fbq;
  const script = document.createElement("script");
  script.async = true;
  script.src = PIXEL_SRC;
  document.head.appendChild(script);
  fbq("init", pixelId);
  fbq("track", "PageView");
}

// Snippet oficial do gtag.js em forma de módulo: `gtag` empurra para o dataLayer até o script carregar.
function loadGa4(measurementId) {
  if (window.gtag) return;
  window.dataLayer = window.dataLayer || [];
  window.gtag = function () {
    window.dataLayer.push(arguments);
  };
  const script = document.createElement("script");
  script.async = true;
  script.src = `${GTAG_SRC}?id=${encodeURIComponent(measurementId)}`;
  document.head.appendChild(script);
  window.gtag("js", new Date());
  window.gtag("config", measurementId);
}

function contents(data) {
  return { content_ids: [data.productId], content_type: "product", content_name: data.productName, value: Number(data.value), currency: data.currency };
}

export function viewContent(data) {
  debug("ViewContent", data);
  window.fbq?.("track", "ViewContent", contents(data));
  window.gtag?.("event", "view_item", { currency: data.currency, value: Number(data.value), items: [{ item_id: data.productId, item_name: data.productName }] });
}

export function initiateCheckout(data) {
  debug("InitiateCheckout", data);
  window.fbq?.("track", "InitiateCheckout", contents(data));
  window.gtag?.("event", "begin_checkout", { currency: data.currency, value: Number(data.value), items: [{ item_id: data.productId, item_name: data.productName }] });
}

// Só renderizado pela Thank You na primeira visita (purchase_tracked_at); eventID = order.event_id
// prepara a deduplicação com a Conversions API.
export function purchase(data) {
  debug("Purchase", data);
  window.fbq?.("track", "Purchase", contents(data), { eventID: data.eventId });
  window.gtag?.("event", "purchase", { transaction_id: data.orderId, currency: data.currency, value: Number(data.value), items: [{ item_id: data.productId, item_name: data.productName }] });
}

export function init(el) {
  if (el.dataset.pixelId) loadPixel(el.dataset.pixelId);
  if (el.dataset.ga4Id) loadGa4(el.dataset.ga4Id);
  if (el.dataset.event === "view_content") viewContent(el.dataset);
  if (el.dataset.event === "purchase") purchase(el.dataset);
}
