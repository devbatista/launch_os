require "rails_helper"

RSpec.describe Orders::MarkPaid do
  let(:capture) { { "id" => "CAP-1", "status" => "COMPLETED" } }
  let(:payer) { { "email_address" => "Jane.Buyer@Example.com", "name" => { "given_name" => "Jane", "surname" => "Buyer" }, "address" => { "country_code" => "US" } } }

  it "marca paid, grava capture id e cria o Client normalizado (T01)" do
    order = create(:order)

    result = described_class.call(order, capture:, payer:, source: :capture)

    expect(result).to be_paid
    expect(result.paid_at).to be_present
    expect(result.paypal_capture_id).to eq("CAP-1")
    expect(result.payer_email).to eq("jane.buyer@example.com")
    expect(result.payer_name).to eq("Jane Buyer")
    client = result.client
    expect(client).to have_attributes(email: "jane.buyer@example.com", name: "Jane Buyer", country: "US")
    expect(client.first_purchase_at).to be_present
    expect(client.last_purchase_at).to be_present
    expect(client.whatsapp_opt_in).to be(false)
    expect(result.download_token).to be_active
    expect(result.download_token.expires_at).to be_within(1.minute).of(7.days.from_now)
  end

  it "reaproveita o token criado no capture PENDING e regenera o revogado por disputa" do
    pending = create(:order)
    token = pending.create_download_token!
    described_class.call(pending, capture:, payer:, source: :webhook)
    expect(pending.reload.download_token).to eq(token)
    expect(token.reload).to be_active

    disputed = create(:order, :disputed)
    revoked = create(:download_token, :revoked, order: disputed)
    described_class.call(disputed, capture: { "id" => "CAP-2" }, payer:, source: :dispute_resolved)
    expect(revoked.reload).to be_active
    expect(revoked.revoked_at).to be_nil
  end

  it "enfileira o DeliverOrderJob uma única vez, depois do commit (T09)" do
    order = create(:order)

    expect { described_class.call(order, capture:, payer:, source: :capture) }
      .to have_enqueued_job(DeliverOrderJob).with(order.id).once
    expect { described_class.call(order, capture:, payer:, source: :webhook) }.not_to have_enqueued_job(DeliverOrderJob)
  end

  it "é idempotente: segunda chamada não muda nada (T12)" do
    order = create(:order)
    described_class.call(order, capture:, payer:, source: :capture)
    paid_at = order.reload.paid_at

    expect { described_class.call(order, capture: { "id" => "OTHER" }, payer:, source: :webhook) }.not_to change(Client, :count)
    expect(order.reload.paypal_capture_id).to eq("CAP-1")
    expect(order.paid_at).to eq(paid_at)
  end

  it "reaproveita o Client existente pelo email e atualiza last_purchase_at" do
    client = create(:client, email: "jane.buyer@example.com", name: "Old Name", first_purchase_at: 1.year.ago, last_purchase_at: 1.year.ago)
    order = create(:order)

    described_class.call(order, capture:, payer:, source: :capture)

    expect(order.reload.client).to eq(client)
    expect(client.reload.name).to eq("Old Name")
    expect(client.last_purchase_at).to be > 1.minute.ago
    expect(client.first_purchase_at).to be < 1.month.ago
  end

  it "grava o opt-in de WhatsApp no Client com telefone, texto exato e data (evidência TCPA)" do
    order = create(:order, :with_whatsapp_opt_in)

    described_class.call(order, capture:, payer:, source: :capture)

    client = order.reload.client
    expect(client.phone).to eq("+14155552671")
    expect(client.whatsapp_opt_in).to be(true)
    expect(client.whatsapp_opt_in_at).to eq(order.created_at)
    expect(client.whatsapp_opt_in_text).to eq(I18n.t("checkout.whatsapp_opt_in", locale: :en))
    expect(client).to be_whatsapp_deliverable
  end

  it "não grava opt-in sem consentimento no checkout" do
    order = create(:order, phone: "+14155552671", whatsapp_opt_in: false)

    described_class.call(order, capture:, payer:, source: :capture)

    expect(order.reload.client.whatsapp_opt_in).to be(false)
    expect(order.client.phone).to be_nil
  end

  it "aceita disputed → paid e rejeita failed/refunded → paid (T25)" do
    disputed = create(:order, :disputed)
    expect(described_class.call(disputed, capture:, payer:, source: :webhook)).to be_paid

    failed = create(:order, :failed)
    expect { described_class.call(failed, capture:, payer:, source: :webhook) }.to raise_error(Orders::InvalidTransition)
    expect(failed.reload).to be_failed

    refunded = create(:order, :refunded)
    expect { described_class.call(refunded, capture:, payer:, source: :webhook) }.to raise_error(Orders::InvalidTransition)
  end
end
