require "rails_helper"

RSpec.describe SendWhatsappMessageJob do
  let(:client) { create(:client, :with_whatsapp_opt_in) }
  let(:order) { create(:order, :paid, client:) }

  before { create(:download_token, order:) }

  context "com Twilio ligado", :twilio do
    it "envia na fila whatsapp e registra MessageLog queued com o SID (T08)" do
      stub_twilio_message(sid: "SMabc")
      expect(described_class.new.queue_name).to eq("whatsapp")

      described_class.perform_now(order.id, template: "order_delivery")

      log = order.message_logs.sole
      expect(log).to have_attributes(channel: "whatsapp", template: "order_delivery", recipient: "+14155552671", status: "queued", provider_message_id: "SMabc")
    end

    it "sem opt-in, com opt-out ou token inativo não envia nem cria log (T10, T20)" do
      order.update!(client: create(:client))
      expect { described_class.perform_now(order.id, template: "order_delivery") }.not_to change(MessageLog, :count)

      order.update!(client:)
      client.opt_out_whatsapp!
      expect { described_class.perform_now(order.id, template: "access_resend") }.not_to change(MessageLog, :count)

      client.update!(whatsapp_opt_in: true, whatsapp_opt_out_at: nil)
      order.download_token.revoke!
      expect { described_class.perform_now(order.id, template: "order_delivery") }.not_to change(MessageLog, :count)
      expect(a_request(:post, TwilioStubs::MESSAGES_URL)).not_to have_been_made
    end

    it "erro 63xxx → log failed com o código, sem retry (T10)" do
      stub_twilio_error(code: 63016, message: "not a WhatsApp user")

      expect { described_class.perform_now(order.id, template: "order_delivery") }.not_to have_enqueued_job(described_class)
      expect(order.message_logs.sole).to have_attributes(status: "failed", error_code: "63016", attempts: 1)
    end

    it "Twilio fora (500) → retry no mesmo log; esgotado → failed. O email já foi e o pedido segue pago (T10)" do
      stub_request(:post, TwilioStubs::MESSAGES_URL).to_return(status: 500, body: "boom")

      expect { described_class.perform_now(order.id, template: "order_delivery") }.to have_enqueued_job(described_class)
      2.times { perform_enqueued_jobs(only: described_class) }

      expect(order.message_logs.count).to eq(1)
      expect(order.message_logs.sole).to have_attributes(status: "failed")
      expect(order.message_logs.sole.attempts).to be >= 3
      expect(order.reload).to be_paid
    end

    it "template desconhecido é erro de programação; pedido inexistente é descartado" do
      expect { described_class.perform_now(order.id, template: "marketing") }.to raise_error(ArgumentError)
      expect { described_class.perform_now(SecureRandom.uuid, template: "order_delivery") }.not_to raise_error
    end
  end

  it "com TWILIO_ENABLED ausente retorna sem enviar nem logar (T27)" do
    expect { described_class.perform_now(order.id, template: "order_delivery") }.not_to change(MessageLog, :count)
    expect(a_request(:post, /api\.twilio\.com/)).not_to have_been_made
  end
end
