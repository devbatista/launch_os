# Sentry (docs/specs/13-seguranca.md). Sem SENTRY_DSN o SDK fica desativado, então dev e test
# não precisam de configuração. sentry-sidekiq reporta jobs mortos e erros no worker.
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production]
  config.environment = Rails.env
  config.release = ENV["RAILWAY_GIT_COMMIT_SHA"].presence

  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Email, telefone e IP do comprador são dados pessoais: nada de PII automático nos eventos.
  config.send_default_pii = false

  # Só monitoramento de erros no MVP (sem tracing/profiling).
  config.traces_sample_rate = 0.0
end
