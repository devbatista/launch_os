require "rails_helper"

RSpec.describe "Orders transitions" do # rubocop:disable RSpec/DescribeClass
  describe Orders::MarkRefunded do
    it "paid|disputed → refunded revogando o token, idempotente; pending não (T07, T25)" do
      paid = create(:order, :paid)
      token = create(:download_token, order: paid)
      expect(described_class.call(paid, source: :webhook)).to be_refunded
      expect(paid.refunded_at).to be_present
      expect(token.reload.revoked_at).to be_present
      expect(described_class.call(paid)).to be_refunded

      disputed = create(:order, :disputed)
      expect(described_class.call(disputed)).to be_refunded

      pending = create(:order)
      expect { described_class.call(pending) }.to raise_error(Orders::InvalidTransition)
    end
  end

  describe Orders::MarkDisputed do
    it "paid → disputed revogando o token, idempotente; pending/refunded não (T18, T25)" do
      paid = create(:order, :paid)
      token = create(:download_token, order: paid)
      expect(described_class.call(paid)).to be_disputed
      expect(paid.disputed_at).to be_present
      expect(token.reload.revoked_at).to be_present
      expect(described_class.call(paid)).to be_disputed

      expect { described_class.call(create(:order)) }.to raise_error(Orders::InvalidTransition)
      expect { described_class.call(create(:order, :refunded)) }.to raise_error(Orders::InvalidTransition)
    end
  end

  describe Orders::ResolveDispute do
    it "a favor do vendedor volta a paid mantendo Client e capture; contra vira refunded" do
      order = create(:order, :disputed, paypal_capture_id: "CAP-D")
      client = order.client

      token = create(:download_token, :revoked, order:)

      described_class.call(order, outcome: "RESOLVED_SELLER_FAVOUR")
      expect(order.reload).to be_paid
      expect(order.client).to eq(client)
      expect(order.paypal_capture_id).to eq("CAP-D")
      expect(token.reload).to be_active

      Orders::MarkDisputed.call(order)
      described_class.call(order, outcome: "RESOLVED_BUYER_FAVOUR")
      expect(order.reload).to be_refunded
    end
  end
end
