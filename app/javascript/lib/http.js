// JSON fetch wrapper: sends the CSRF token and X-Requested-With, parses JSON responses and
// turns 4xx/5xx into an HttpError carrying the parsed body (e.g. { error: "..." }).

export class HttpError extends Error {
  constructor(response, body) {
    super(body?.error || `HTTP ${response.status}`);
    this.name = "HttpError";
    this.status = response.status;
    this.body = body;
  }
}

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content ?? "";
}

function parseBody(text) {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

export async function request(method, url, body = undefined) {
  const headers = {
    Accept: "application/json",
    "X-CSRF-Token": csrfToken(),
    "X-Requested-With": "XMLHttpRequest",
  };
  if (body !== undefined) headers["Content-Type"] = "application/json";

  const response = await fetch(url, {
    method,
    headers,
    credentials: "same-origin",
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const parsed = parseBody(await response.text());
  if (!response.ok) throw new HttpError(response, parsed);
  return parsed;
}

export const get = (url) => request("GET", url);
export const post = (url, body) => request("POST", url, body);
export const patch = (url, body) => request("PATCH", url, body);
export const destroy = (url, body) => request("DELETE", url, body);
