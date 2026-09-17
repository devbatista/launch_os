// Coleções da LP no admin (benefits, testimonials, faqs) — spec 05.
// Intercepta o submit de qualquer form dentro do container, envia por fetch (form-encoded, mesmo
// payload do submit normal, incluindo _method) e troca o innerHTML pelo partial devolvido —
// tanto no 200 (lista reordenada) quanto no 422 (lista com erros). Sem JS, o form segue seu
// caminho normal e o servidor responde com redirect.
const csrfToken = () => document.querySelector('meta[name="csrf-token"]')?.content ?? "";

export function init(el) {
  el.addEventListener("submit", async (event) => {
    const form = event.target;
    if (!(form instanceof HTMLFormElement)) return;

    // Confirmação (modules/admin/confirm.js) já cancelou o evento? Então não enviamos.
    if (event.defaultPrevented) return;
    event.preventDefault();

    const submitter = event.submitter;
    const body = new FormData(form, submitter);
    el.setAttribute("aria-busy", "true");
    form.querySelectorAll("button, input[type=submit]").forEach((b) => (b.disabled = true));

    try {
      const response = await fetch(form.action, {
        method: "POST",
        body,
        headers: {
          Accept: "text/html",
          "X-CSRF-Token": csrfToken(),
          "X-Requested-With": "XMLHttpRequest",
        },
        credentials: "same-origin",
      });

      if (response.ok || response.status === 422) {
        el.innerHTML = await response.text();
      } else {
        throw new Error(`HTTP ${response.status}`);
      }
    } catch (error) {
      console.error("[admin/nested_list] request failed, submitting normally", error);
      form.querySelectorAll("button, input[type=submit]").forEach((b) => (b.disabled = false));
      form.submit();
    } finally {
      el.removeAttribute("aria-busy");
    }
  });
}
