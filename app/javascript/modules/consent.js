// Banner de cookies (spec 10): informa o uso de cookies/pixels; "OK" grava lo_consent por 1 ano.
// Não bloqueia o Pixel (tráfego dos EUA no MVP) — só informa; a Privacy Policy detalha.
//
//   <div data-module="consent" hidden> … <button data-consent-accept>OK</button></div>
import * as cookies from "lib/cookies";

const COOKIE = "lo_consent";

export function init(el) {
  if (cookies.get(COOKIE)) return;

  el.hidden = false;
  el.querySelector("[data-consent-accept]")?.addEventListener("click", () => {
    cookies.set(COOKIE, "1", { days: 365 });
    el.hidden = true;
  });
}
