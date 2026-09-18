module Orders
  # paid|disputed → refunded (PAYMENT.CAPTURE.REFUNDED/REVERSED ou disputa perdida). Idempotente.
  # Revoga o download token; o email de reembolso (2.6) entra aqui quando existir.
  class MarkRefunded
    def self.call(order, source: nil) = new.call(order, source:)

    def call(order, source: nil)
      order.with_lock do
        return order if order.refunded?
        raise InvalidTransition, "#{order.status} → refunded (#{source})" unless order.paid? || order.disputed?

        order.update!(status: :refunded, refunded_at: Time.current)
        order.download_token&.revoke!
        Rails.logger.info { "[orders] #{order.id} refunded via #{source}" }
      end
      order
    end
  end
end
