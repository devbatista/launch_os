# Envia um email do OrderMailer (order_delivery, access_resend, refund_confirmation) registrando um
# MessageLog (spec 09). Providers::TransientError → retry 3× com backoff, mantendo o mesmo log `queued`;
# esgotadas as tentativas ou em Providers::PermanentError → log `failed` + Sentry, sem retry.
class SendOrderEmailJob < ApplicationJob
  queue_as :mailers

  TEMPLATES = { "order_delivery" => :delivery, "access_resend" => :access_resend,
                "refund_confirmation" => :refund_confirmation }.freeze

  retry_on Providers::TransientError, wait: :polynomially_longer, attempts: 3 do |job, error|
    job.fail_log!(error)
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(order_id, template:)
    action = TEMPLATES.fetch(template)
    @order = Order.includes(:client, :product, :download_token).find(order_id)
    @template = template
    return Rails.logger.warn { "[mail] #{@order.id} #{template}: no recipient email" } if recipient.blank?

    mail = OrderMailer.with(order: @order).public_send(action).deliver_now
    log.mark_sent!(mail.message_id)
    Rails.logger.info { "[mail] #{@order.id} #{template} sent to #{log.client_id || "payer"} message_id=#{mail.message_id}" }
  rescue Providers::TransientError => e
    log.register_attempt!(e)
    raise
  rescue Providers::PermanentError => e
    fail_log!(e)
  end

  def fail_log!(error)
    log&.mark_failed!(error)
    Rails.logger.error { "[mail] #{@order&.id} #{@template}: #{error.message}" }
    Sentry.capture_exception(error) if defined?(Sentry)
  end

  private
    def recipient = @order.client&.email || @order.payer_email

    # Um log por envio; nos retries reaproveita o que ficou `queued`.
    def log
      return @log if defined?(@log)
      return nil unless @order

      @log = @order.message_logs.channel_email.queued.find_by(template: @template) ||
             @order.message_logs.create!(client: @order.client, channel: :email, template: @template, recipient:)
    end
end
