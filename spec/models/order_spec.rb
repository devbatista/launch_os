require "rails_helper"

RSpec.describe Order do
  it "gera event_id na criação e começa pending" do
    order = create(:order)

    expect(order).to be_pending
    expect(order.event_id).to match(/\A[0-9a-f-]{36}\z/)
    expect(order.amount).to eq(BigDecimal("14.90"))
  end

  it "exige valor positivo, moeda de 3 letras e telefone E.164" do
    expect(build(:order, amount_cents: 0)).not_to be_valid
    expect(build(:order, currency: "US")).not_to be_valid
    expect(build(:order, phone: "4155552671")).not_to be_valid
    expect(build(:order, phone: "+14155552671")).to be_valid
    expect(build(:order, phone: nil)).to be_valid
  end

  it "não aceita opt-in de WhatsApp sem telefone" do
    expect(build(:order, whatsapp_opt_in: true, phone: nil)).not_to be_valid
    expect(build(:order, :with_whatsapp_opt_in)).to be_valid
  end

  it "impõe unicidade de paypal_order_id e paypal_capture_id" do
    create(:order, paypal_order_id: "A", paypal_capture_id: "C")

    expect(build(:order, paypal_order_id: "A")).not_to be_valid
    expect(build(:order, paypal_capture_id: "C")).not_to be_valid
    expect(build(:order, paypal_order_id: nil, paypal_capture_id: nil)).to be_valid
  end

  it "impede excluir produto com pedidos e o marca como não deletável" do
    order = create(:order)

    expect(order.product).not_to be_deletable
    expect { order.product.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end
