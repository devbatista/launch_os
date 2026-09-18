require "rails_helper"

RSpec.describe DeliverOrderJob do
  it "enfileira o email order_delivery para pedido pago com token ativo (T09)" do
    order = create(:order, :paid)
    create(:download_token, order:)

    expect { described_class.perform_now(order.id) }
      .to have_enqueued_job(SendOrderEmailJob).with(order.id, template: "order_delivery").on_queue("mailers")
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
