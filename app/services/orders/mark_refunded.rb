module Orders
  # paid|disputed → refunded (PAYMENT.CAPTURE.REFUNDED/REVERSED ou disputa perdida). Idempotente.
  # Revogação do download token (2.4) e email de reembolso (2.6) entram aqui quando existirem.
  class MarkRefunded
    def self.call(order, source: nil) = new.call(order, source:)

    def call(order, source: nil)
      order.with_lock do
        return order if order.refunded?
        raise InvalidTransition, "#{order.status} → refunded (#{source})" unless order.paid? || order.disputed?

        order.update!(status: :refunded, refunded_at: Time.current)
        Rails.logger.info { "[orders] #{order.id} refunded via #{source}" }
      end
      order
    end
  end
end
