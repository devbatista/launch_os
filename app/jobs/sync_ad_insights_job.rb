# Sync periódico do Insights da Meta (config/schedule.yml, sidekiq-cron). Sem argumentos usa a janela
# padrão de MetaAds::SyncInsights; datas ISO8601 servem para backfill manual
# (`SyncAdInsightsJob.perform_later("2026-10-02")`). No-op sem META_ACCESS_TOKEN/META_AD_ACCOUNT_ID.
# Transitório → retry; permanente (token inválido, permissão) → Sentry e descarta: o próximo ciclo tenta de novo.
class SyncAdInsightsJob < ApplicationJob
  queue_as :default

  retry_on Providers::TransientError, wait: :polynomially_longer, attempts: 3 do |_job, error|
    report(error)
  end
  discard_on(Providers::PermanentError) { |_job, error| report(error) }

  def self.report(error)
    Rails.logger.error { "[ads] sync de insights falhou: #{error.message}" }
    Sentry.capture_exception(error) if defined?(Sentry)
  end

  def perform(since = nil, until_date = nil)
    return unless MetaAds.insights_enabled?

    MetaAds::SyncInsights.call(since: since && Date.iso8601(since), until_date: until_date && Date.iso8601(until_date))
  end
end
