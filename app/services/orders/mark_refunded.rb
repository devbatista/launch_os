module Orders
  # paid|disputed → refunded (PAYMENT.CAPTURE.REFUNDED/REVERSED ou disputa perdida). Idempotente.
  # Revoga o download token e, após o commit, enfileira o email de confirmação do reembolso.
  class MarkRefunded
    def self.call(order, source: nil) = new.call(order, source:)

    def call(order, source: nil)
      transitioned = false
      order.with_lock do
        next if order.refunded?
        raise InvalidTransition, "#{order.status} → refunded (#{source})" unless order.paid? || order.disputed?

        order.update!(status: :refunded, refunded_at: Time.current)
        order.download_token&.revoke!
        Rails.logger.info { "[orders] #{order.id} refunded via #{source}" }
        transitioned = true
      end
      SendOrderEmailJob.perform_later(order.id, template: "refund_confirmation") if transitioned
      order
    end
  end
end
