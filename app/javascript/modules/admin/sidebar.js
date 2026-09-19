// Sidebar off-canvas no mobile: [data-sidebar-open] abre, [data-sidebar-close] (botão e backdrop) e Esc fecham.
// No desktop (lg) a sidebar é fixa e o estado não interfere (CSS em tailwind/application.css, .adm-sidebar*).
const OPEN_CLASS = "adm-sidebar-open";

export function init(root) {
  const html = document.documentElement;
  const set = (open) => html.classList.toggle(OPEN_CLASS, open);

  root.querySelectorAll("[data-sidebar-open]").forEach((el) => el.addEventListener("click", () => set(true)));
  root.querySelectorAll("[data-sidebar-close]").forEach((el) => el.addEventListener("click", () => set(false)));
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") set(false);
  });
}
