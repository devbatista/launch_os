require "rails_helper"

RSpec.describe ProcessPaypalWebhookJob do
  def event_for(type, order, resource: nil, id: "WH-#{SecureRandom.hex(3)}")
    create(:webhook_event, external_id: id, event_type: type,
                           payload: paypal_event(type, id:, resource: resource || capture_resource(order)))
  end

  it "PAYMENT.CAPTURE.COMPLETED → paid (fecha o navegador após aprovar) e correlaciona o evento (T05)" do
    order = create(:order)
    event = event_for("PAYMENT.CAPTURE.COMPLETED", order, resource: capture_resource(order, id: "CAP-WH"))

    described_class.perform_now(event.id)

    expect(order.reload).to be_paid
    expect(order.paypal_capture_id).to eq("CAP-WH")
    expect(event.reload).to be_processed
    expect(event.order).to eq(order)
    expect(event.processed_at).to be_present
  end

  it "é no-op para pedido já pago pelo capture do front (T17)" do
    order = create(:order, :paid, paypal_capture_id: "CAP-FRONT")
    event = event_for("PAYMENT.CAPTURE.COMPLETED", order, resource: capture_resource(order, id: "CAP-FRONT"))

    expect { described_class.perform_now(event.id) }.not_to change { order.reload.paid_at }
    expect(order.paypal_capture_id).to eq("CAP-FRONT")
    expect(order.client).to be_present
    expect(event.reload).to be_processed
  end

  it "localiza o pedido por supplementary_data.order_id quando custom_id falta" do
    order = create(:order)
    resource = capture_resource(order).except("custom_id")
    event = event_for("PAYMENT.CAPTURE.COMPLETED", order, resource:)

    described_class.perform_now(event.id)

    expect(order.reload).to be_paid
  end

  it "PENDING mantém pending e grava o motivo; DENIED → failed" do
    order = create(:order)
    pending = event_for("PAYMENT.CAPTURE.PENDING", order, resource: capture_resource(order, status: "PENDING", extra: { "status_details" => { "reason" => "RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION" } }))
    described_class.perform_now(pending.id)
    expect(order.reload).to be_pending
    expect(order.pending_reason).to eq("RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION")
    expect(pending.reload).to be_processed

    denied = event_for("PAYMENT.CAPTURE.DENIED", order, resource: capture_resource(order, status: "DENIED"))
    described_class.perform_now(denied.id)
    expect(order.reload).to be_failed
  end

  it "REFUNDED → refunded; REVERSED idem" do
    order = create(:order, :paid)
    event = event_for("PAYMENT.CAPTURE.REFUNDED", order, resource: { "id" => "REF-1", "custom_id" => order.id })

    described_class.perform_now(event.id)

    expect(order.reload).to be_refunded
    expect(order.refunded_at).to be_present
    expect(event.reload).to be_processed
  end

  it "DISPUTE.CREATED → disputed pelo seller_transaction_id; RESOLVED a favor volta a paid, contra vira refunded (T18)" do
    order = create(:order, :paid, paypal_capture_id: "CAP-DISP")
    dispute = { "dispute_id" => "PP-D-1", "disputed_transactions" => [ { "seller_transaction_id" => "CAP-DISP" } ] }

    created = event_for("CUSTOMER.DISPUTE.CREATED", order, resource: dispute)
    described_class.perform_now(created.id)
    expect(order.reload).to be_disputed
    expect(created.reload.order).to eq(order)

    won = event_for("CUSTOMER.DISPUTE.RESOLVED", order, resource: dispute.merge("dispute_outcome" => { "outcome_code" => "RESOLVED_SELLER_FAVOUR" }))
    described_class.perform_now(won.id)
    expect(order.reload).to be_paid
    expect(order.client).to be_present

    Orders::MarkDisputed.call(order)
    lost = event_for("CUSTOMER.DISPUTE.RESOLVED", order, resource: dispute.merge("dispute_outcome" => { "outcome_code" => "RESOLVED_BUYER_FAVOUR" }))
    described_class.perform_now(lost.id)
    expect(order.reload).to be_refunded
  end

  it "CHECKOUT.ORDER.APPROVED só correlaciona; tipos desconhecidos e pedido inexistente ficam ignored" do
    order = create(:order)
    approved = event_for("CHECKOUT.ORDER.APPROVED", order, resource: { "id" => order.paypal_order_id })
    described_class.perform_now(approved.id)
    expect(approved.reload).to be_ignored
    expect(approved.order).to eq(order)
    expect(order.reload).to be_pending

    unknown = event_for("BILLING.PLAN.CREATED", order, resource: {})
    described_class.perform_now(unknown.id)
    expect(unknown.reload).to be_ignored

    orphan = event_for("PAYMENT.CAPTURE.COMPLETED", order, resource: { "id" => "X", "custom_id" => SecureRandom.uuid })
    described_class.perform_now(orphan.id)
    expect(orphan.reload).to be_ignored
    expect(orphan.error).to eq("order not found")
  end

  it "transição inválida marca o evento como failed sem levantar (T25)" do
    order = create(:order, :refunded)
    event = event_for("PAYMENT.CAPTURE.COMPLETED", order)

    expect { described_class.perform_now(event.id) }.not_to raise_error
    expect(event.reload).to be_failed
    expect(event.error).to include("refunded → paid")
    expect(order.reload).to be_refunded
  end

  it "erro inesperado marca o evento como failed, reporta ao Sentry e relança (fica visível no Sidekiq)" do
    order = create(:order)
    event = event_for("PAYMENT.CAPTURE.COMPLETED", order)
    allow(Orders::MarkPaid).to receive(:call).and_raise(RuntimeError, "boom")
    allow(Sentry).to receive(:capture_exception)

    expect { described_class.perform_now(event.id) }.to raise_error(RuntimeError, "boom")
    expect(event.reload).to be_failed
    expect(event.error).to eq("boom")
    expect(Sentry).to have_received(:capture_exception).with(an_instance_of(RuntimeError))
  end

  it "não reprocessa evento que não está received e descarta id inexistente" do
    order = create(:order)
    event = event_for("PAYMENT.CAPTURE.COMPLETED", order)
    event.mark_processed!

    described_class.perform_now(event.id)
    expect(order.reload).to be_pending

    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
  end
end
