// Confirmação de ações destrutivas no admin: <form data-confirm="Excluir?"> (button_to com
// form: { data: { confirm: } }) ou <a data-confirm>. Escuta na fase de captura para decidir
// antes de qualquer outro handler (ex.: modules/admin/nested_list.js).
export function init() {
  document.addEventListener(
    "submit",
    (event) => {
      const message = event.target?.dataset?.confirm;
      if (message && !window.confirm(message)) {
        event.preventDefault();
        event.stopImmediatePropagation();
      }
    },
    true
  );

  document.addEventListener(
    "click",
    (event) => {
      const link = event.target?.closest?.("a[data-confirm]");
      if (link && !window.confirm(link.dataset.confirm)) {
        event.preventDefault();
        event.stopImmediatePropagation();
      }
    },
    true
  );
}
