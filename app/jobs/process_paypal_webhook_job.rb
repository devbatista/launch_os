# Processa um WebhookEvent do PayPal (spec 07, passo 5) fora do request. Roteia por event_type para os
# services Orders::*; marca processed/ignored/failed no evento. Erros transitórios (PayPal fora) tentam de
# novo; evento inexistente é descartado; transição inválida vira `failed` sem derrubar o job.
class ProcessPaypalWebhookJob < ApplicationJob
  queue_as :webhooks

  retry_on Providers::TransientError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(webhook_event_id)
    event = WebhookEvent.find(webhook_event_id)
    return unless event.received? # já processado (reentrega ou retry após sucesso)

    resource = event.payload["resource"] || {}
    case event.event_type
    when "PAYMENT.CAPTURE.COMPLETED"
      with_order(event, resource) { |order| Orders::MarkPaid.call(order, capture: resource, payer: payer_from(resource), source: :webhook) }
    when "PAYMENT.CAPTURE.PENDING"
      with_order(event, resource) { |order| order.update!(paypal_capture_id: resource["id"].presence || order.paypal_capture_id, pending_reason: resource.dig("status_details", "reason")) }
    when "PAYMENT.CAPTURE.DENIED", "PAYMENT.CAPTURE.DECLINED"
      with_order(event, resource) { |order| Orders::MarkFailed.call(order, reason: event.event_type) }
    when "PAYMENT.CAPTURE.REFUNDED", "PAYMENT.CAPTURE.REVERSED"
      with_order(event, resource) { |order| Orders::MarkRefunded.call(order, source: :webhook) }
    when "CUSTOMER.DISPUTE.CREATED"
      with_order(event, resource, by: :dispute) { |order| Orders::MarkDisputed.call(order, source: :webhook) }
    when "CUSTOMER.DISPUTE.RESOLVED"
      with_order(event, resource, by: :dispute) { |order| Orders::ResolveDispute.call(order, outcome: resource.dig("dispute_outcome", "outcome_code"), source: :webhook) }
    when "CHECKOUT.ORDER.APPROVED"
      # O capture é feito pelo front; só correlacionamos. (Fallback de capture server-side: 2.3, opcional.)
      order = Order.find_by(paypal_order_id: resource["id"])
      event.mark_ignored!("approved; capture is done by the client", order:)
    else
      event.mark_ignored!("unhandled event type")
    end
  rescue Orders::InvalidTransition => e
    event.mark_failed!(e.message)
    Rails.logger.error { "[webhooks/paypal] #{event.id} #{event.event_type}: #{e.message}" }
    Sentry.capture_exception(e) if defined?(Sentry)
  rescue Providers::TransientError
    raise # retry_on
  rescue StandardError => e
    event.mark_failed!(e.message)
    Sentry.capture_exception(e) if defined?(Sentry)
    raise
  end

  private
    def with_order(event, resource, by: :capture)
      order = by == :dispute ? order_from_dispute(resource) : order_from_capture(resource)
      return event.mark_ignored!("order not found") unless order

      yield order
      event.mark_processed!(order:)
    end

    # PAYMENT.CAPTURE.*: custom_id (= order.id) ou o id do pedido do PayPal em supplementary_data.
    def order_from_capture(resource)
      custom = resource["custom_id"].to_s
      order = Order.find_by(id: custom) if custom.match?(/\A[0-9a-f-]{36}\z/)
      order ||= Order.find_by(paypal_order_id: resource.dig("supplementary_data", "related_ids", "order_id"))
      order || Order.find_by(paypal_capture_id: resource["id"])
    end

    # CUSTOMER.DISPUTE.*: seller_transaction_id = paypal_capture_id.
    def order_from_dispute(resource)
      ids = Array(resource["disputed_transactions"]).filter_map { |t| t["seller_transaction_id"] }
      Order.find_by(paypal_capture_id: ids) if ids.any?
    end

    # Captures não trazem o pagador; MarkPaid mantém o Client existente (capture do front) ou fica sem Client.
    def payer_from(resource)
      email = resource.dig("payer", "email_address") || resource.dig("supplementary_data", "payer", "email_address")
      email ? { "email_address" => email } : nil
    end
end
