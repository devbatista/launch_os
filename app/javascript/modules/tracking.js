// Eventos de marketing (spec 10): ViewContent, InitiateCheckout, Purchase. Por enquanto só wrappers
// no-op com um log em dev; a integração com Meta Pixel e GA4 entra na Fase 4 (tarefa 4.1),
// respeitando o preview (@preview) e o consentimento. Chamado por modules/checkout.js.
function emit(name, data = {}) {
  if (window.__lo_tracking_debug) console.debug("[tracking]", name, data);
}

export function viewContent(data) {
  emit("ViewContent", data);
}

export function initiateCheckout(data) {
  emit("InitiateCheckout", { product_id: data.productId });
}

export function purchase(data) {
  emit("Purchase", data);
}

// <section data-module="tracking" data-event="purchase" data-event-id data-value data-currency>
// A Thank You só renderiza isso na primeira visita (purchase_tracked_at) — dedup no servidor.
export function init(el) {
  if (el.dataset.event === "purchase") purchase(el.dataset);
}
