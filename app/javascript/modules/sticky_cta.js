// Barra de compra fixa no mobile (spec 06): aparece quando o usuário rola além do hero e some
// enquanto o hero ou o bloco de oferta (#buy) estão visíveis. Sem IntersectionObserver
// (navegador muito antigo), a barra simplesmente não aparece.
//
//   <div data-module="sticky_cta" data-hide-when="#hero, #buy" hidden>…</div>
export function init(el) {
  if (!("IntersectionObserver" in window)) return;

  const watched = document.querySelectorAll(el.dataset.hideWhen ?? "#hero, #buy");
  if (!watched.length) return;

  const visible = new Set();
  const io = new IntersectionObserver((entries) => {
    entries.forEach((entry) => (entry.isIntersecting ? visible.add(entry.target) : visible.delete(entry.target)));
    el.hidden = visible.size > 0;
  }, { threshold: 0.1 });

  watched.forEach((section) => io.observe(section));
}
