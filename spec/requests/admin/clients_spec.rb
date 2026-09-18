require "rails_helper"

RSpec.describe "Admin clients" do
  it "exige sessão" do
    client = create(:client)
    get admin_clients_path
    expect(response).to redirect_to(admin_login_path)
    get admin_client_path(client)
    expect(response).to redirect_to(admin_login_path)
    post revoke_whatsapp_opt_in_admin_client_path(client)
    expect(response).to redirect_to(admin_login_path)
  end

  context "quando autenticado" do
    before { sign_in_admin }

    it "lista com telefone mascarado, contagem de pedidos pagos, busca e filtro de opt-in" do
      jane = create(:client, :with_whatsapp_opt_in, name: "Jane Buyer", email: "jane@example.com")
      create_list(:order, 2, :paid, client: jane)
      create(:order, :refunded, client: jane)
      john = create(:client, name: "John Doe", email: "john@example.com")

      get admin_clients_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jane Buyer", "John Doe", "+1 ••• ••• 2671", "Opt-in")
      expect(response.body).not_to include("+14155552671")
      expect(response.body).to match(%r{jane@example.com.*?<td[^>]*>2</td>}m)

      get admin_clients_path(q: "JOHN")
      expect(response.body).to include("John Doe")
      expect(response.body).not_to include("Jane Buyer")

      get admin_clients_path(opt_in: "1")
      expect(response.body).to include("Jane Buyer")
      expect(response.body).not_to include("John Doe")
    end

    it "detalhe mostra opt-in com texto e data, pedidos e mensagens; revogar opt-in grava opt-out" do
      client = create(:client, :with_whatsapp_opt_in)
      order = create(:order, :paid, client:)
      create(:download_token, order:)
      create(:message_log, :sent, order:, client:)

      get admin_client_path(client)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("checkout.whatsapp_opt_in", locale: :en), "Opt-in ativo", order.id.first(8), "ativo · 0/10", "order_delivery", "Revogar opt-in")

      post revoke_whatsapp_opt_in_admin_client_path(client)
      expect(response).to redirect_to(admin_client_path(client))
      expect(client.reload).not_to be_whatsapp_deliverable
      expect(client.whatsapp_opt_out_at).to be_present

      follow_redirect!
      expect(response.body).to include("Sem envio")
      expect(response.body).not_to include("Revogar opt-in")
    end
  end
end
