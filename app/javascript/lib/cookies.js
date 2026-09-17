// First-party cookie helpers (attribution cookie lo_attr, visitor id lo_vid, consent lo_consent).

export function get(name) {
  const prefix = `${encodeURIComponent(name)}=`;
  const entry = document.cookie.split("; ").find((c) => c.startsWith(prefix));
  return entry ? decodeURIComponent(entry.slice(prefix.length)) : null;
}

export function set(name, value, { days = 30, path = "/", sameSite = "Lax" } = {}) {
  const expires = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toUTCString();
  const secure = location.protocol === "https:" ? "; Secure" : "";
  document.cookie =
    `${encodeURIComponent(name)}=${encodeURIComponent(value)}` +
    `; expires=${expires}; path=${path}; SameSite=${sameSite}${secure}`;
}

export function remove(name, { path = "/" } = {}) {
  document.cookie = `${encodeURIComponent(name)}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=${path}`;
}
