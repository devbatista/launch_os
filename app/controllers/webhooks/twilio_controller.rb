module Webhooks
  # Callbacks da Twilio (spec 09): status das mensagens enviadas e mensagens recebidas (STOP → opt-out;
  # qualquer texto vai por email ao suporte). Sem sessão nem CSRF; X-Twilio-Signature obrigatória —
  # inválida → 403 sem gravar nada. Cada chamada vira um WebhookEvent (auditoria/idempotência).
  class TwilioController < ActionController::API
    STOP_WORDS = %w[STOP UNSUBSCRIBE CANCEL END QUIT].freeze
    STATUS_TIMESTAMPS = { "sent" => :sent_at, "delivered" => :delivered_at, "read" => :read_at,
                          "failed" => :failed_at, "undelivered" => :failed_at }.freeze

    before_action :verify_signature!
    before_action :require_message_sid

    # MessageSid, MessageStatus (queued|sending|sent|delivered|read|failed|undelivered), ErrorCode.
    def status
      sid, status = params[:MessageSid].to_s, params[:MessageStatus].to_s
      event = record_event("#{sid}-#{status}")
      return head :no_content unless event # reentrega

      log = MessageLog.channel_whatsapp.find_by(provider_message_id: sid)
      if log && MessageLog.statuses.key?(status)
        attrs = { status: }
        attrs[STATUS_TIMESTAMPS[status]] = Time.current if STATUS_TIMESTAMPS[status]
        attrs[:error_code] = params[:ErrorCode].presence if status.in?(%w[failed undelivered])
        log.update!(attrs)
        event.mark_processed!(order: log.order)
      else
        event.mark_ignored!(log ? "status #{status} not tracked" : "no message log for #{sid}")
      end
      head :no_content
    end

    # From (whatsapp:+E164), Body, MessageSid. STOP → opt-out; tudo é encaminhado ao suporte. Resposta:
    # TwiML vazio (sem auto-resposta no MVP).
    def inbound
      event = record_event(params[:MessageSid].to_s)
      return render_empty_twiml unless event

      phone = params[:From].to_s.delete_prefix("whatsapp:")
      body = params[:Body].to_s
      client = Client.find_by(phone:)
      order = client&.orders&.recent&.first
      opted_out = STOP_WORDS.include?(body.strip.upcase) && client&.whatsapp_opt_in? == true
      client.opt_out_whatsapp! if opted_out

      # MessageLog exige pedido; número sem cliente/pedido fica só no WebhookEvent e no email ao suporte.
      MessageLog.create!(order:, client:, channel: :whatsapp, template: :inbound, recipient: phone, status: :delivered,
                         delivered_at: Time.current, provider_message_id: params[:MessageSid]) if order
      SupportMailer.with(phone:, body:, client:, opted_out:).inbound_whatsapp.deliver_later
      event.mark_processed!(order:)
      Rails.logger.info { "[webhooks/twilio] inbound client=#{client&.id || 'unknown'} opt_out=#{opted_out}" }
      render_empty_twiml
    end

    private
      def verify_signature!
        return if twilio_client.valid_signature?(url: request.original_url, params: webhook_params, signature: request.headers["X-Twilio-Signature"]) ||
                  twilio_client.valid_signature?(url: request.original_url.sub(/\Ahttp:/, "https:"), params: webhook_params, signature: request.headers["X-Twilio-Signature"])

        Rails.logger.warn { "[webhooks/twilio] invalid signature ip=#{request.remote_ip} path=#{request.path}" }
        head :forbidden
      end

      def require_message_sid
        head :bad_request if params[:MessageSid].blank?
      end

      # Só os parâmetros do corpo POST (form-encoded), sem os de rota/formato do Rails.
      def webhook_params = request.request_parameters.to_h

      def twilio_client = @twilio_client ||= Providers::Twilio::Client.new

      # nil quando o evento já foi registrado (Twilio reenvia callbacks).
      def record_event(external_id)
        WebhookEvent.create!(provider: "twilio", external_id:, event_type: action_name, signature_valid: true,
                             payload: webhook_params, headers: { "X-Twilio-Signature" => request.headers["X-Twilio-Signature"] })
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
        raise e if e.is_a?(ActiveRecord::RecordInvalid) && e.record.errors.where(:external_id, :taken).empty?

        nil
      end

      def render_empty_twiml
        render xml: "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response></Response>"
      end
  end
end
