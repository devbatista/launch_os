// Botão "olho" do campo de senha (login): alterna type=password/text e os ícones [data-eye].
export function init(root) {
  root.querySelectorAll("[data-password-toggle]").forEach((button) => {
    const input = button.parentElement.querySelector("[data-password-input]");
    if (!input) return;

    button.addEventListener("click", () => {
      const show = input.type === "password";
      input.type = show ? "text" : "password";
      button.setAttribute("aria-pressed", String(show));
      button.querySelector('[data-eye="show"]').classList.toggle("hidden", show);
      button.querySelector('[data-eye="hide"]').classList.toggle("hidden", !show);
      input.focus();
    });
  });
}
