module Orders
  # pending → failed (capture recusado/DENIED). Idempotente.
  class MarkFailed
    def self.call(order, reason: nil) = new.call(order, reason:)

    def call(order, reason: nil)
      order.with_lock do
        return order if order.failed?
        raise InvalidTransition, "#{order.status} → failed" unless order.pending?

        order.update!(status: :failed, failed_at: Time.current)
        Rails.logger.info { "[orders] #{order.id} failed#{" (#{reason})" if reason}" }
      end
      order
    end
  end
end
