require "rails_helper"

RSpec.describe Delivery::ResendAccess do
  it "com token ativo só reenvia; expirado ou no limite regenera antes (T19)" do
    order = create(:order, :paid)
    token = create(:download_token, order:)

    expect { expect(described_class.call(order)).to be(true) }
      .to have_enqueued_job(SendOrderEmailJob).with(order.id, template: "access_resend")
    expect(token.reload.token).to eq(token.token)

    expired = create(:download_token, :expired, order: create(:order, :paid))
    old = expired.token
    described_class.call(expired.order)
    expect(expired.reload.token).not_to eq(old)
    expect(expired).to be_active

    limit = create(:download_token, :limit_reached, order: create(:order, :paid))
    described_class.call(limit.order)
    expect(limit.reload.download_count).to eq(0)
  end

  it "cria o token quando o pedido pago não tem nenhum" do
    order = create(:order, :paid)
    expect { described_class.call(order) }.to have_enqueued_job(SendOrderEmailJob)
    expect(order.reload.download_token).to be_active
  end

  it "não reenvia token revogado nem pedido não pago/reembolsado" do
    revoked = create(:download_token, :revoked, order: create(:order, :paid))
    expect { expect(described_class.call(revoked.order)).to be(false) }.not_to have_enqueued_job
    expect(revoked.reload.revoked_at).to be_present

    expect(described_class.call(create(:order))).to be(false)
    expect(described_class.call(create(:order, :refunded))).to be(false)
  end

  it "channels sem :email não enfileira email" do
    order = create(:order, :paid)
    create(:download_token, order:)
    expect { described_class.call(order, channels: [ :whatsapp ]) }.not_to have_enqueued_job(SendOrderEmailJob)
  end
end
