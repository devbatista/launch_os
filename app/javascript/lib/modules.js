// Activates JS modules declared in the HTML.
//
//   <section id="buy" data-module="checkout" data-product-id="...">
//
// imports modules/checkout.js and calls its `init(el)`. Several modules can share one element
// (data-module="attribution tracking"). Modules under modules/admin/ are referenced with the
// prefix: data-module="admin/nested_list". Configuration travels in data-* attributes, never in
// inline scripts.
const READY_ATTRIBUTE = "data-module-ready";

export function activate(root = document) {
  root.querySelectorAll(`[data-module]:not([${READY_ATTRIBUTE}])`).forEach((el) => {
    el.setAttribute(READY_ATTRIBUTE, "");

    el.dataset.module
      .split(/\s+/)
      .filter(Boolean)
      .forEach((name) => {
        import(`modules/${name}`)
          .then((mod) => mod.init?.(el))
          .catch((error) => console.error(`[modules] failed to load "${name}"`, error));
      });
  });
}
