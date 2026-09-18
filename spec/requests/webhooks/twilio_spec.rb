require "rails_helper"

# Callbacks da Twilio (spec 09): assinatura obrigatória; status atualiza o MessageLog; inbound STOP → opt-out
# e qualquer mensagem vai por email ao suporte.
RSpec.describe "Twilio webhooks", :twilio do
  let(:client) { create(:client, :with_whatsapp_opt_in, name: "Jane Buyer") }
  let(:order) { create(:order, :paid, client:) }
  let!(:log) { create(:message_log, :whatsapp, order:, client:, provider_message_id: "SM1") }

  describe "POST /webhooks/twilio/status" do
    it "assinatura inválida → 403 e nada gravado (T11)" do
      post_twilio_webhook("/webhooks/twilio/status", { "MessageSid" => "SM1", "MessageStatus" => "delivered" }, valid: false)

      expect(response).to have_http_status(:forbidden)
      expect(log.reload).to be_queued
      expect(WebhookEvent.count).to eq(0)
    end

    it "sent → delivered → read atualizam o log com timestamps; reentrega é ignorada (T08)" do
      post_twilio_webhook("/webhooks/twilio/status", { "MessageSid" => "SM1", "MessageStatus" => "sent" })
      expect(response).to have_http_status(:no_content)
      expect(log.reload).to be_sent
      expect(log.sent_at).to be_present

      post_twilio_webhook("/webhooks/twilio/status", { "MessageSid" => "SM1", "MessageStatus" => "delivered" })
      expect(log.reload).to be_delivered
      expect(log.delivered_at).to be_present

      post_twilio_webhook("/webhooks/twilio/status", { "MessageSid" => "SM1", "MessageStatus" => "read" })
      expect(log.reload).to be_read

      expect { post_twilio_webhook("/webhooks/twilio/status", { "MessageSid" => "SM1", "MessageStatus" => "read" }) }.not_to change(WebhookEvent, :count)
      expect(response).to have_http_status(:no_content)
      expect(WebhookEvent.where(provider: "twilio").pluck(:external_id)).to contain_exactly("SM1-sent", "SM1-delivered", "SM1-read")
      expect(WebhookEvent.last.order).to eq(order)
    end

    it "failed/undelivered gravam error_code; status desconhecido ou SID sem log são ignorados" do
      post_twilio_webhook("/webhooks/twilio/status", { "MessageSid" => "SM1", "MessageStatus" => "undelivered", "ErrorCode" => "63016" })
      expect(log.reload).to have_attributes(status: "undelivered", error_code: "63016")
      expect(log.failed_at).to be_present

      post_twilio_webhook("/webhooks/twilio/status", { "MessageSid" => "SM1", "MessageStatus" => "sending" })
      expect(WebhookEvent.find_by(external_id: "SM1-sending")).to be_ignored

      post_twilio_webhook("/webhooks/twilio/status", { "MessageSid" => "SMunknown", "MessageStatus" => "delivered" })
      expect(response).to have_http_status(:no_content)
      expect(WebhookEvent.find_by(external_id: "SMunknown-delivered")).to be_ignored

      post_twilio_webhook("/webhooks/twilio/status", { "MessageStatus" => "delivered" })
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /webhooks/twilio/inbound" do
    it "STOP → opt-out, MessageLog inbound, email ao suporte e TwiML vazio (T20)" do
      params = { "MessageSid" => "SMin1", "From" => "whatsapp:+14155552671", "To" => "whatsapp:+14155238886", "Body" => " stop " }

      expect { post_twilio_webhook("/webhooks/twilio/inbound", params) }
        .to have_enqueued_job(ActionMailer::MailDeliveryJob).with("SupportMailer", "inbound_whatsapp", "deliver_now", hash_including(params: hash_including(opted_out: true)))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<Response></Response>")
      expect(client.reload).not_to be_whatsapp_deliverable
      expect(client.whatsapp_opt_out_at).to be_present
      inbound = order.message_logs.template_inbound.sole
      expect(inbound).to have_attributes(recipient: "+14155552671", status: "delivered", provider_message_id: "SMin1")

      # Reenvio via admin/recuperação não dispara mais WhatsApp para este cliente.
      expect { Delivery::ResendAccess.call(order, channels: [ :email, :whatsapp ]) }.not_to have_enqueued_job(SendWhatsappMessageJob)
    end

    it "mensagem comum não altera o opt-in; número desconhecido só vai ao suporte" do
      post_twilio_webhook("/webhooks/twilio/inbound", { "MessageSid" => "SMin2", "From" => "whatsapp:+14155552671", "Body" => "Hi, the link doesn't open" })
      expect(client.reload).to be_whatsapp_deliverable
      expect(order.message_logs.template_inbound.count).to eq(1)

      expect { post_twilio_webhook("/webhooks/twilio/inbound", { "MessageSid" => "SMin3", "From" => "whatsapp:+12025550123", "Body" => "STOP" }) }
        .to have_enqueued_job(ActionMailer::MailDeliveryJob).and(not_change(MessageLog, :count))
      expect(WebhookEvent.find_by(external_id: "SMin3")).to be_processed
    end

    it "assinatura inválida → 403" do
      post_twilio_webhook("/webhooks/twilio/inbound", { "MessageSid" => "SMin4", "From" => "whatsapp:+14155552671", "Body" => "STOP" }, valid: false)
      expect(response).to have_http_status(:forbidden)
      expect(client.reload).to be_whatsapp_deliverable
    end
  end
end
