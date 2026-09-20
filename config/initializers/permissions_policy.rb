# Permissions-Policy (docs/specs/13-seguranca.md). O `config.permissions_policy` do Rails 8.1 ainda
# emite só o header legado `Feature-Policy`, então o header atual vai direto nos default_headers.
# O app não usa nenhuma dessas APIs e a negação vale também para os iframes do PayPal; `payment`
# fica no padrão (self) porque o SDK pode usar a Payment Request API dentro do próprio iframe.
Rails.application.config.action_dispatch.default_headers["Permissions-Policy"] =
  "camera=(), microphone=(), geolocation=(), usb=(), gyroscope=(), magnetometer=(), payment=(self)"
