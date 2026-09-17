// Preview local dos arquivos escolhidos na seção "Arquivos" do produto (spec 05) — antes do upload.
// Para cada <input type="file"> do container mostra nome, tamanho e (se imagem) uma miniatura no
// <div data-preview> seguinte. Avisa quando o arquivo passa de data-max-bytes ou não bate com `accept`;
// a validação de verdade é a do modelo, isto aqui só evita um round-trip inútil.
const MB = 1024 * 1024;
const formatSize = (bytes) => (bytes >= MB ? `${(bytes / MB).toFixed(1)} MB` : `${Math.ceil(bytes / 1024)} KB`);

function problemsFor(file, input) {
  const problems = [];
  const maxBytes = Number(input.dataset.maxBytes);
  const accepted = (input.accept || "").split(",").map((t) => t.trim()).filter(Boolean);

  if (maxBytes && file.size > maxBytes) problems.push(`acima de ${formatSize(maxBytes)}`);
  if (accepted.length && !accepted.includes(file.type)) problems.push("tipo não aceito");
  return problems;
}

function renderFile(file, input) {
  const item = document.createElement("div");
  item.className = "flex items-center gap-2";

  if (file.type.startsWith("image/")) {
    const img = document.createElement("img");
    img.className = "h-10 w-10 rounded object-cover";
    img.alt = "";
    img.src = URL.createObjectURL(file);
    img.addEventListener("load", () => URL.revokeObjectURL(img.src), { once: true });
    item.append(img);
  }

  const problems = problemsFor(file, input);
  const text = document.createElement("span");
  text.className = problems.length ? "text-red-600" : "text-gray-600";
  text.textContent = `${file.name} (${formatSize(file.size)})${problems.length ? ` — ${problems.join(", ")}` : ""}`;
  item.append(text);
  return item;
}

export function init(el) {
  el.addEventListener("change", (event) => {
    const input = event.target;
    if (!(input instanceof HTMLInputElement) || input.type !== "file") return;

    const preview = input.parentElement?.querySelector("[data-preview]");
    if (!preview) return;

    preview.replaceChildren(...Array.from(input.files ?? [], (file) => renderFile(file, input)));
  });
}
