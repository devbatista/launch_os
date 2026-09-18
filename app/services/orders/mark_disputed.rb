module Orders
  # paid → disputed (CUSTOMER.DISPUTE.CREATED). Idempotente. Revogação do token entra na 2.4.
  class MarkDisputed
    def self.call(order, source: nil) = new.call(order, source:)

    def call(order, source: nil)
      order.with_lock do
        return order if order.disputed?
        raise InvalidTransition, "#{order.status} → disputed (#{source})" unless order.paid?

        order.update!(status: :disputed, disputed_at: Time.current)
        Rails.logger.warn { "[orders] #{order.id} disputed via #{source}" }
      end
      order
    end
  end
end
