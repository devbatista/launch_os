# Content Security Policy (docs/specs/13-seguranca.md). Uma política só para LP e admin; cada
# origem externa está aqui pelo motivo ao lado. Não há script nem <style> inline no app: os únicos
# inline são os dois <script> do importmap (que o importmap-rails já emite com nonce), o <style> que
# o Trix injeta no admin (lê <meta name="csp-nonce">) e os que o SDK do PayPal cria (recebe o nonce
# em data-csp-nonce, ver modules/checkout.js). Por isso script-src e style-src levam nonce e
# 'unsafe-inline' não aparece em lugar nenhum.
#
# Nonce por requisição (SecureRandom, não a sessão: a LP não abre sessão). A LP é cacheada pelo
# Thruster com o header junto, então cada cópia em cache repete o mesmo nonce durante o max-age —
# isso não enfraquece nada aqui porque nenhum conteúdo de usuário entra em <script>/<style> inline.
# O 304 do `stale?` sai sem Content-Type, logo sem CSP, e o navegador mantém o header da cópia dele.
#
# Violações vão para o Sentry (Security Policy Reports) em produção, quando há SENTRY_DSN — o navegador
# reporta direto, então em dev/test o header sai sem report-uri para não poluir o projeto.
Rails.application.configure do
  s3_origin = ENV["S3_ENDPOINT"].presence || "https://*.amazonaws.com"
  paypal = %w[https://www.paypal.com https://www.sandbox.paypal.com]

  # DSN https://<chave>@o<org>.ingest.sentry.io/<projeto> → endpoint de Security Reports do Sentry.
  # A chave do DSN é pública por definição (vai no header para o navegador).
  sentry_report_uri = Rails.env.production? && ENV["SENTRY_DSN"].presence&.then do |dsn|
    uri = URI(dsn)
    "#{uri.scheme}://#{uri.host}/api#{uri.path}/security/?sentry_key=#{uri.user}"
  end

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.frame_ancestors :none
    policy.form_action :self

    # PayPal JS SDK; Meta Pixel; GA4 (gtag.js).
    policy.script_src :self, *paypal, "https://connect.facebook.net", "https://www.googletagmanager.com"
    # Google Fonts (Inter, só no admin).
    policy.style_src :self, "https://fonts.googleapis.com"
    policy.font_src :self, :data, "https://fonts.gstatic.com"
    # Capas/mockups vêm do bucket por URL assinada (redirect do Active Storage); pixels de imagem
    # da Meta (tr e o log de erros do fbevents) e do GA; ícones do PayPal.
    policy.img_src :self, :data, s3_origin, "https://www.facebook.com", "https://connect.facebook.net",
                   "https://*.paypal.com", "https://*.paypalobjects.com", "https://*.google-analytics.com"
    # Chamadas do SDK do PayPal (inclui logger), do Pixel (tr) e do GA4.
    policy.connect_src :self, "https://*.paypal.com", "https://www.facebook.com",
                       "https://*.google-analytics.com", "https://*.analytics.google.com",
                       "https://*.googletagmanager.com", "https://stats.g.doubleclick.net"
    # Botões e checkout do PayPal renderizam em iframes.
    policy.frame_src(*paypal)

    policy.report_uri sentry_report_uri if sentry_report_uri
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
