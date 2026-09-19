// Atribuição first-touch (spec 10). Na LP: grava o cookie lo_attr (UTMs, fbclid, referrer, landing_path;
// 30 dias) só se ainda não existir, garante o lo_vid (UUID, 1 ano) e manda um beacon POST /visits — a
// LP é cacheada, então é o beacon que conta a visita. _fbp/_fbc são do Pixel e ficam com o servidor.
//
//   <main data-module="attribution" data-product="slug">
import * as cookies from "lib/cookies";

const ATTR_COOKIE = "lo_attr";
const VISITOR_COOKIE = "lo_vid";
const KEYS = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term", "fbclid"];

function paramsFromUrl() {
  const search = new URLSearchParams(location.search);
  const data = {};
  KEYS.forEach((key) => {
    const value = search.get(key);
    if (value) data[key] = value.slice(0, 255);
  });
  if (document.referrer && !document.referrer.startsWith(location.origin)) data.referrer = document.referrer.slice(0, 255);
  data.landing_path = location.pathname.slice(0, 255);
  return data;
}

function ensureAttribution() {
  const existing = cookies.get(ATTR_COOKIE);
  if (existing) {
    try {
      return JSON.parse(existing);
    } catch {
      /* cookie corrompido: regrava */
    }
  }
  const data = paramsFromUrl();
  cookies.set(ATTR_COOKIE, JSON.stringify(data), { days: 30 });
  return data;
}

function ensureVisitorId() {
  let id = cookies.get(VISITOR_COOKIE);
  if (!id) {
    id = crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
    cookies.set(VISITOR_COOKIE, id, { days: 365 });
  }
  return id;
}

function beacon(payload) {
  const body = JSON.stringify(payload);
  if (navigator.sendBeacon) {
    navigator.sendBeacon("/visits", new Blob([body], { type: "application/json" }));
  } else {
    fetch("/visits", { method: "POST", headers: { "Content-Type": "application/json" }, body, keepalive: true }).catch(() => {});
  }
}

export function init(el) {
  const attribution = ensureAttribution();
  const visitorId = ensureVisitorId();
  const current = paramsFromUrl(); // a visita atual leva os parâmetros desta URL, não os do first-touch
  beacon({ product: el.dataset.product, path: location.pathname, visitor_id: visitorId, ...current, first_touch: attribution.landing_path });
}
