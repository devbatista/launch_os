// Botão "Copiar": <button data-module="admin/copy" data-copy-text="https://…">
export function init(el) {
  const original = el.textContent;

  el.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(el.dataset.copyText ?? "");
      el.textContent = "Copiado!";
    } catch {
      el.textContent = "Falhou";
    }
    setTimeout(() => (el.textContent = original), 1500);
  });
}
