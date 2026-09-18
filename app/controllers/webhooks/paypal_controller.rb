module Webhooks
  # POST /webhooks/paypal (spec 07, passo 4): confirmação server-to-server. Sem sessão nem CSRF
  # (ActionController::API). Verifica a assinatura, grava o evento (idempotente por (provider, external_id)),
  # enfileira o processamento e responde 2xx rápido — o PayPal reenvia se não receber 2xx em ~30 s.
  class PaypalController < ActionController::API
    SIGNATURE_HEADERS = Providers::Paypal::VerifyWebhookSignature::SIGNATURE_HEADERS

    def create
      raw = request.raw_post
      event = JSON.parse(raw)
      return head :bad_request unless event.is_a?(Hash) && event["id"].present? && event["event_type"].present?

      verified = Providers::Paypal::VerifyWebhookSignature.call(headers: request.headers, body: raw)
      webhook_event = record(event, verified)

      unless verified
        Rails.logger.warn { "[webhooks/paypal] invalid signature for #{event['id']} (#{event['event_type']})" }
        Sentry.capture_message("PayPal webhook with invalid signature", level: :warning, extra: { event_id: event["id"] }) if defined?(Sentry)
        return head :bad_request
      end

      ProcessPaypalWebhookJob.perform_later(webhook_event.id) if webhook_event.received?
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private
      # Uma linha por evento do PayPal; reenvio do mesmo id → devolve a existente sem reprocessar.
      def record(event, verified)
        WebhookEvent.create_with(event_type: event["event_type"], payload: event, headers: signature_headers,
                                 signature_valid: verified, status: verified ? "received" : "ignored",
                                 error: (verified ? nil : "invalid signature"))
                    .find_or_create_by!(provider: "paypal", external_id: event["id"])
      rescue ActiveRecord::RecordNotUnique
        WebhookEvent.find_by!(provider: "paypal", external_id: event["id"])
      end

      def signature_headers
        SIGNATURE_HEADERS.index_with { |h| request.headers[h] }.compact
      end
  end
end
