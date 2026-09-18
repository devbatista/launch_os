module Orders
  # paid → disputed (CUSTOMER.DISPUTE.CREATED). Idempotente. Revoga o download token até a resolução.
  class MarkDisputed
    def self.call(order, source: nil) = new.call(order, source:)

    def call(order, source: nil)
      order.with_lock do
        return order if order.disputed?
        raise InvalidTransition, "#{order.status} → disputed (#{source})" unless order.paid?

        order.update!(status: :disputed, disputed_at: Time.current)
        order.download_token&.revoke!
        Rails.logger.warn { "[orders] #{order.id} disputed via #{source}" }
      end
      order
    end
  end
end
