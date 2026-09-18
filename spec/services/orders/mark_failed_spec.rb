require "rails_helper"

RSpec.describe Orders::MarkFailed do
  it "marca pending → failed com failed_at, idempotente" do
    order = create(:order)

    expect(described_class.call(order, reason: "DECLINED")).to be_failed
    expect(order.failed_at).to be_present
    expect(described_class.call(order)).to be_failed
  end

  it "não aceita paid → failed (T25)" do
    order = create(:order, :paid)

    expect { described_class.call(order) }.to raise_error(Orders::InvalidTransition)
    expect(order.reload).to be_paid
  end
end
