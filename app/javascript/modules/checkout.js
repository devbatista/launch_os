// Checkout embutido na LP (spec 06/07). Carrega o SDK do PayPal sob demanda (IntersectionObserver,
// quando #buy se aproxima) e renderiza os botões: createOrder → POST /checkout/paypal (o servidor
// define o preço), onApprove → POST /checkout/paypal/capture. Sem framework, sem SDK no servidor.
//
//   <section id="buy" data-module="checkout" data-product-id data-paypal-client-id
//            data-create-url data-capture-url data-whatsapp-enabled>
import * as http from "lib/http";
import * as tracking from "modules/tracking";

const SDK_URL = "https://www.paypal.com/sdk/js";

export function init(el) {
  if (!el.dataset.paypalClientId) return showMessage(el, "Checkout is not configured yet.", "error");

  const io = new IntersectionObserver(
    ([entry]) => {
      if (!entry.isIntersecting) return;
      io.disconnect();
      loadSdk(el).then(() => renderButtons(el)).catch(() => showMessage(el, "We couldn't load the payment form. Please refresh the page or try again later.", "error"));
    },
    { rootMargin: "400px" },
  );
  io.observe(el);
}

function loadSdk(el) {
  if (window.paypal) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const params = new URLSearchParams({
      "client-id": el.dataset.paypalClientId,
      currency: "USD",
      intent: "capture",
      "disable-funding": "paylater",
    });
    const script = document.createElement("script");
    script.src = `${SDK_URL}?${params}`;
    script.async = true;
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

function renderButtons(el) {
  const form = el.querySelector("form");
  const container = el.querySelector("#paypal-button-container");
  const fallback = el.querySelector("[data-checkout-fallback]");

  return window.paypal
    .Buttons({
      style: { layout: "vertical", label: "pay", shape: "rect" },

      onClick: () => tracking.initiateCheckout(el.dataset),

      createOrder: async () => {
        hideMessage(el);
        const { paypal_order_id } = await http.post(el.dataset.createUrl, {
          product_id: el.dataset.productId,
          phone: form.elements.phone?.value ?? "",
          whatsapp_opt_in: form.elements.whatsapp_opt_in?.checked ?? false,
        });
        return paypal_order_id;
      },

      onApprove: async ({ orderID }) => {
        showMessage(el, "Confirming your payment…", "info");
        const result = await http.post(el.dataset.captureUrl, { paypal_order_id: orderID });
        if (result.thank_you_url) return window.location.assign(result.thank_you_url);
        if (result.status === "pending") {
          return showMessage(el, "Thanks! Your payment is being processed by PayPal. We'll email your download link as soon as it clears — no need to pay again.", "info");
        }
        showMessage(el, "Payment received! Your download link is on its way to your email.", "success");
        el.querySelector("#paypal-button-container")?.setAttribute("hidden", "");
      },

      onCancel: () => hideMessage(el),

      onError: (error) => {
        console.error("[checkout]", error);
        showMessage(el, error?.body?.error || "Something went wrong. Please try again or contact support.", "error");
      },
    })
    .render(container)
    .then(() => fallback?.remove());
}

const TONES = {
  info: "border-white/30 bg-white/10 text-slate-100",
  success: "border-emerald-400 bg-emerald-500/20 text-emerald-100",
  error: "border-red-400 bg-red-500/20 text-red-100",
};

function showMessage(el, text, tone = "info") {
  const box = el.querySelector("[data-checkout-message]");
  if (!box) return;
  box.textContent = text;
  box.className = `mt-4 rounded-lg border px-4 py-3 text-center text-base font-medium ${TONES[tone]}`;
  box.hidden = false;
  box.scrollIntoView({ block: "nearest", behavior: "smooth" });
}

function hideMessage(el) {
  const box = el.querySelector("[data-checkout-message]");
  if (box) box.hidden = true;
}
