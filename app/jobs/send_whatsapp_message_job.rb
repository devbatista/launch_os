# Envia o template de WhatsApp (order_delivery ou access_resend) registrando um MessageLog (spec 09).
# A Twilio aceita e devolve o SID com status "queued"; sent/delivered/read/failed chegam depois pelo
# status callback (Webhooks::TwilioController#status). Transitório → retry 3× no mesmo log; permanente
# (63xxx, 21xxx) ou esgotado → log `failed` + Sentry. Falha aqui nunca afeta o email nem o pedido.
class SendWhatsappMessageJob < ApplicationJob
  queue_as :whatsapp

  TEMPLATES = %w[order_delivery access_resend].freeze

  retry_on Providers::TransientError, wait: :polynomially_longer, attempts: 3 do |job, error|
    job.fail_log!(error)
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(order_id, template:)
    raise ArgumentError, "unknown WhatsApp template #{template.inspect}" unless TEMPLATES.include?(template)
    return unless Delivery.whatsapp_enabled?

    @order = Order.includes(:client, :product, :download_token).find(order_id)
    @template = template
    return unless @order.client&.whatsapp_deliverable? && @order.download_token&.active?

    sid = Whatsapp::SendTemplateMessage.call(@order)
    log.update!(provider_message_id: sid, error_code: nil, error_message: nil)
    Rails.logger.info { "[whatsapp] #{@order.id} #{template} accepted sid=#{sid}" }
  rescue Providers::TransientError => e
    log.register_attempt!(e)
    raise
  rescue Providers::PermanentError => e
    fail_log!(e)
  end

  def fail_log!(error)
    log&.mark_failed!(error, code: error.respond_to?(:code) ? error.code.to_s : nil)
    Rails.logger.error { "[whatsapp] #{@order&.id} #{@template}: #{error.message}" }
    Sentry.capture_exception(error) if defined?(Sentry)
  end

  private
    def log
      return @log if defined?(@log)
      return nil unless @order

      @log = @order.message_logs.channel_whatsapp.queued.find_by(template: @template) ||
             @order.message_logs.create!(client: @order.client, channel: :whatsapp, template: @template, recipient: @order.client.phone)
    end
end
