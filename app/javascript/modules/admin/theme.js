// Tema claro/escuro do admin. Sem escolha salva, vale a preferência do sistema (CSS, prefers-color-scheme);
// o clique em [data-theme-toggle] fixa o oposto do que está visível e guarda em localStorage ("light"|"dark").
// Aplica cedo no carregamento para reduzir o flash ao trocar de página.
const KEY = "adm-theme";

function apply(theme) {
  if (theme === "light" || theme === "dark") document.documentElement.dataset.theme = theme;
  else delete document.documentElement.dataset.theme;
}

function current() {
  const chosen = document.documentElement.dataset.theme;
  if (chosen) return chosen;
  return window.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

export function init(root) {
  try {
    apply(localStorage.getItem(KEY));
  } catch {
    // localStorage indisponível (modo privado etc.): fica a preferência do sistema.
  }

  root.querySelectorAll("[data-theme-toggle]").forEach((button) =>
    button.addEventListener("click", () => {
      const next = current() === "dark" ? "light" : "dark";
      apply(next);
      try {
        localStorage.setItem(KEY, next);
      } catch {
        // ignorar
      }
    })
  );
}
