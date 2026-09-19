require "rails_helper"

# GET /thank-you/:id (spec 08, decisão 18/09 / T21): confirma o pagamento, diz para onde o link foi e
# NUNCA expõe o link nem o token; Purchase marcado uma única vez.
RSpec.describe "Thank you page" do
  it "confirma o pagamento e o email de entrega sem mostrar o link de download" do
    order = create(:order, :paid, client: create(:client, name: "Jane Buyer", email: "jane@example.com"))
    token = create(:download_token, order:)

    get thank_you_path(order)

    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.body).to include("Thank you, Jane!", order.product.name, "jane@example.com", "7 days", "/access/recover")
    expect(response.body).to include('<meta name="robots" content="noindex,nofollow">')
    expect(response.body).not_to include(token.token, "/download/")
  end

  it "marca purchase_tracked_at e renderiza o evento só na primeira visita (T21)" do
    order = create(:order, :paid)

    get thank_you_path(order)
    expect(order.reload.purchase_tracked_at).to be_present
    expect(response.body).to include('data-event="purchase"', %(data-event-id="#{order.event_id}"), %(data-order-id="#{order.id}"), %(data-product-name="#{order.product.name}"), 'data-currency="USD"')
    tracked_at = order.purchase_tracked_at

    get thank_you_path(order)
    expect(response.body).not_to include('data-event="purchase"')
    expect(order.reload.purchase_tracked_at).to eq(tracked_at)
  end

  it "mostra 'processing' para pedido pending, sem tracking" do
    order = create(:order)

    get thank_you_path(order)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("being processed", "No need to pay again")
    expect(response.body).not_to include('data-event="purchase"')
    expect(order.reload.purchase_tracked_at).to be_nil
  end

  it "mostra 'no longer active' para failed/refunded/disputed" do
    %i[failed refunded disputed].each do |status|
      get thank_you_path(create(:order, status))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("no longer active")
    end
  end

  it "responde 404 para id desconhecido" do
    get thank_you_path("nope")
    expect(response).to have_http_status(:not_found)

    get thank_you_path(SecureRandom.uuid)
    expect(response).to have_http_status(:not_found)
  end
end
