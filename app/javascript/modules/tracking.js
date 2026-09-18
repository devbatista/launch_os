// Eventos de marketing (spec 10): ViewContent, InitiateCheckout, Purchase. Por enquanto só wrappers
// no-op com um log em dev; a integração com Meta Pixel e GA4 entra na Fase 3 (tarefa 3.1),
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

export function init() {}
