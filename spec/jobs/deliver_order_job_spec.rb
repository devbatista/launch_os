require "rails_helper"

RSpec.describe DeliverOrderJob do
  it "enfileira o email order_delivery para pedido pago com token ativo (T09)" do
    order = create(:order, :paid)
    create(:download_token, order:)

    expect { described_class.perform_now(order.id) }
      .to have_enqueued_job(SendOrderEmailJob).with(order.id, template: "order_delivery").on_queue("mailers")
  end

  it "com Twilio ligado e opt-in enfileira também o WhatsApp; sem opt-in só o email", :twilio do
    with_opt_in = create(:order, :paid, client: create(:client, :with_whatsapp_opt_in))
    create(:download_token, order: with_opt_in)
    expect { described_class.perform_now(with_opt_in.id) }
      .to have_enqueued_job(SendWhatsappMessageJob).with(with_opt_in.id, template: "order_delivery").on_queue("whatsapp")
      .and have_enqueued_job(SendOrderEmailJob)

    without = create(:order, :paid)
    create(:download_token, order: without)
    expect { described_class.perform_now(without.id) }.to have_enqueued_job(SendOrderEmailJob)
    expect(SendWhatsappMessageJob).not_to have_been_enqueued.with(without.id, template: "order_delivery")
  end

  it "não entrega pedido não pago, sem token ou com token inativo (refund entre o pagamento e o job)" do
    expect { described_class.perform_now(create(:order).id) }.not_to have_enqueued_job(SendOrderEmailJob)

    paid = create(:order, :paid)
    expect { described_class.perform_now(paid.id) }.not_to have_enqueued_job(SendOrderEmailJob)

    create(:download_token, :revoked, order: paid)
    expect { described_class.perform_now(paid.id) }.not_to have_enqueued_job(SendOrderEmailJob)

    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
  end
end
