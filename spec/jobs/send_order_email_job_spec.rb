require "rails_helper"

RSpec.describe SendOrderEmailJob do
  let(:order) { create(:order, :paid) }

  before { create(:download_token, order:) }

  it "envia o template pedido na fila mailers e registra MessageLog sent com o Message-ID" do
    expect(described_class.new.queue_name).to eq("mailers")

    expect { described_class.perform_now(order.id, template: "order_delivery") }
      .to change { ActionMailer::Base.deliveries.count }.by(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to start_with("Your download is ready")
    log = order.message_logs.sole
    expect(log).to have_attributes(channel: "email", template: "order_delivery", recipient: order.client.email, client: order.client, status: "sent")
    expect(log.provider_message_id).to eq(mail.message_id)
    expect(log.sent_at).to be_present
  end

  it "erro transitório: mantém o log queued com a tentativa e agenda retry; esgotado → failed" do
    allow(OrderMailer).to receive(:with).and_raise(Providers::TransientError, "SES TooManyRequests")

    expect { described_class.perform_now(order.id, template: "access_resend") }.to have_enqueued_job(described_class)
    log = order.message_logs.sole
    expect(log).to be_queued
    expect(log.attempts).to eq(1)

    # Tentativas 2 e 3 reaproveitam o mesmo log; a última (attempts: 3 esgotado) marca failed.
    2.times { perform_enqueued_jobs(only: described_class) }
    expect(order.message_logs.count).to eq(1)
    expect(log.reload).to be_failed
    expect(log.attempts).to be >= 3
    expect(log.error_message).to include("TooManyRequests")
  end

  it "erro permanente: log failed sem retry" do
    allow(OrderMailer).to receive(:with).and_raise(Providers::PermanentError, "SES MessageRejected: not verified")

    expect { described_class.perform_now(order.id, template: "order_delivery") }.not_to have_enqueued_job
    expect(order.message_logs.sole).to have_attributes(status: "failed", attempts: 1)
    expect(order.message_logs.sole.error_message).to include("MessageRejected")
  end

  it "sem email do destinatário não envia nem cria log; pedido inexistente é descartado; template desconhecido falha" do
    order.update!(client: nil, payer_email: nil)
    expect { described_class.perform_now(order.id, template: "order_delivery") }.not_to change { ActionMailer::Base.deliveries.count }
    expect(order.message_logs).to be_empty

    expect { described_class.perform_now(SecureRandom.uuid, template: "order_delivery") }.not_to raise_error
    expect { described_class.perform_now(order.id, template: "marketing") }.to raise_error(KeyError)
  end
end
