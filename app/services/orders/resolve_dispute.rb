module Orders
  # CUSTOMER.DISPUTE.RESOLVED (ou decisão manual no admin): vendedor ganhou → volta a paid;
  # perdeu → refunded. Idempotente por delegar a MarkPaid/MarkRefunded.
  class ResolveDispute
    SELLER_WON = %w[RESOLVED_SELLER_FAVOUR RESOLVED_SELLER_FAVOR].freeze

    def self.call(order, outcome:, source: nil) = new.call(order, outcome:, source:)

    def call(order, outcome:, source: nil)
      if SELLER_WON.include?(outcome.to_s) || outcome.to_s == "paid"
        return order if order.paid?
        MarkPaid.call(order, capture: { "id" => order.paypal_capture_id }, payer: nil, source: source || :dispute_resolved)
      else
        MarkRefunded.call(order, source: source || :dispute_resolved)
      end
    end
  end
end
