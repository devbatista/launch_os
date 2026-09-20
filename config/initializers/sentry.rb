# Sentry (docs/specs/13-seguranca.md). Sem SENTRY_DSN o SDK fica desativado, então dev e test
# não precisam de configuração. sentry-sidekiq reporta jobs mortos e erros no worker.
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production]
  config.environment = Rails.env
  config.release = ENV["RAILWAY_GIT_COMMIT_SHA"].presence

  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # `exit` em scripts de runner/rake não é erro.
  config.excluded_exceptions += [ "SystemExit" ]

  # Email, telefone e IP do comprador são dados pessoais: nada de PII automático nos eventos.
  config.send_default_pii = false

  # Só monitoramento de erros no MVP (sem tracing/profiling).
  config.traces_sample_rate = 0.0

  # Jobs com retry (SendOrderEmailJob, SendWhatsappMessageJob…) só viram evento quando as tentativas
  # acabam — erro transitório que se resolve na 2ª tentativa não polui o Sentry. Jobs sem retry
  # reportam na primeira falha. Dead jobs continuam visíveis em /admin/sidekiq.
  config.sidekiq.report_after_job_retries = true
end
