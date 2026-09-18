require "rails_helper"

RSpec.describe MessageLog do
  it { is_expected.to belong_to(:order) }
  it { is_expected.to belong_to(:client).optional }
  it { is_expected.to validate_presence_of(:recipient) }

  it "nasce queued e transita para sent (limpando erro) ou failed (contando a tentativa)" do
    log = create(:message_log)
    expect(log).to be_queued

    log.register_attempt!(Providers::TransientError.new("SES TooManyRequests"))
    expect(log).to be_queued
    expect(log.attempts).to eq(1)
    expect(log.error_message).to include("TooManyRequests")

    log.mark_sent!("abc@email.amazonses.com")
    expect(log).to be_sent
    expect(log.provider_message_id).to eq("abc@email.amazonses.com")
    expect(log.sent_at).to be_present
    expect(log.error_message).to be_nil

    other = create(:message_log)
    other.mark_failed!(Providers::PermanentError.new("SES MessageRejected: x" * 200), code: "MessageRejected")
    expect(other).to be_failed
    expect(other.failed_at).to be_present
    expect(other.error_code).to eq("MessageRejected")
    expect(other.error_message.length).to be <= 1000
  end

  it "cascata: apagar o pedido apaga os logs; apagar o cliente só desvincula" do
    log = create(:message_log)
    client = log.client
    client.destroy!
    expect(log.reload.client_id).to be_nil
    log.order.destroy!
    expect(described_class.exists?(log.id)).to be(false)
  end
end
