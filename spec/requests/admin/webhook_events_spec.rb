require "rails_helper"

RSpec.describe "Admin webhook events" do
  it "exige sessão" do
    get admin_webhook_events_path
    expect(response).to redirect_to(admin_login_path)
  end

  context "quando autenticado" do
    before { sign_in_admin }

    it "lista com filtros de provedor/status e mostra o payload bruto" do
      order = create(:order, :paid)
      processed = create(:webhook_event, :capture_completed, order:, status: "processed")
      processed.update!(order:)
      failed = create(:webhook_event, event_type: "PAYMENT.CAPTURE.REFUNDED", status: "failed", error: "paid → refunded (webhook)")

      get admin_webhook_events_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("PAYMENT.CAPTURE.COMPLETED", "PAYMENT.CAPTURE.REFUNDED", "Processado", "Falhou", order.id.first(8))

      get admin_webhook_events_path(status: "failed")
      expect(response.body).to include(admin_webhook_event_path(failed))
      expect(response.body).not_to include(admin_webhook_event_path(processed))

      get admin_webhook_events_path(provider: "twilio")
      expect(response.body).to include("Nenhum evento")

      get admin_webhook_event_path(processed)
      expect(response.body).to include(processed.external_id, "custom_id", order.id, admin_order_path(order))
    end
  end
end
