require "rails_helper"

# POST /checkout/paypal e /capture (spec 07): preço do backend, atribuição do cookie, idempotência.
RSpec.describe "Checkout PayPal", :paypal do
  let(:product) { create(:product, :published, price_cents: 1490, slug: "reset") }
  let(:json) { { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" } }

  before { stub_paypal_token }

  # O ambiente de teste desliga a proteção CSRF; aqui ligamos de propósito para simular a LP cacheada.
  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  describe "POST /checkout/paypal" do
    it "cria o Order pending com o preço do produto e devolve o paypal_order_id" do
      stub_paypal_create_order(id: "ORD-1")

      post "/checkout/paypal", params: { product_id: product.id }.to_json, headers: json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq("paypal_order_id" => "ORD-1")
      order = Order.sole
      expect(order).to have_attributes(status: "pending", amount_cents: 1490, currency: "USD", paypal_order_id: "ORD-1", product:)
      expect(order.event_id).to be_present
      expect(order.ip_address).to be_present
    end

    it "ignora amount vindo do cliente: o PayPal recebe o preço do produto (T04)" do
      stub = stub_request(:post, "#{PaypalStubs::BASE}/v2/checkout/orders")
        .with { |req| JSON.parse(req.body).dig("purchase_units", 0, "amount", "value") == "14.90" }
        .to_return(status: 201, body: { id: "ORD-2" }.to_json, headers: json_headers)

      post "/checkout/paypal", params: { product_id: product.id, amount: "0.01", amount_cents: 1, price: "0.01" }.to_json, headers: json

      expect(response).to have_http_status(:created)
      expect(stub).to have_been_requested
      expect(Order.sole.amount_cents).to eq(1490)
    end

    it "normaliza o telefone para E.164 e só aceita opt-in com telefone" do
      stub_paypal_create_order

      post "/checkout/paypal", params: { product_id: product.id, phone: "(415) 555-2671", whatsapp_opt_in: true }.to_json, headers: json
      expect(Order.last).to have_attributes(phone: "+14155552671", whatsapp_opt_in: true)

      post "/checkout/paypal", params: { product_id: product.id, phone: "abc", whatsapp_opt_in: true }.to_json, headers: json
      expect(Order.last).to have_attributes(phone: nil, whatsapp_opt_in: false)
    end

    it "copia a atribuição do cookie lo_attr e os cookies do Pixel (spec 10)" do
      stub_paypal_create_order
      attr = { utm_source: "facebook", utm_medium: "paid", utm_campaign: "launch-1", utm_content: "video-a", utm_term: "focus",
               fbclid: "IwAR123", referrer: "https://l.facebook.com/", landing_path: "/reset", ignored: "x" }
      cookies["lo_attr"] = attr.to_json
      cookies["_fbp"] = "fb.1.1700000000.123456"
      cookies["_fbc"] = "fb.1.1700000000.IwAR123"

      post "/checkout/paypal", params: { product_id: product.id }.to_json, headers: json

      expect(Order.sole).to have_attributes(utm_source: "facebook", utm_medium: "paid", utm_campaign: "launch-1", utm_content: "video-a", utm_term: "focus",
                                            fbclid: "IwAR123", referrer: "https://l.facebook.com/", landing_path: "/reset",
                                            fbp: "fb.1.1700000000.123456", fbc: "fb.1.1700000000.IwAR123")
    end

    it "usa os params da requisição quando não há cookie, e ignora cookie inválido" do
      stub_paypal_create_order
      cookies["lo_attr"] = "not-json"

      post "/checkout/paypal", params: { product_id: product.id, utm_source: "newsletter", utm_campaign: "x" * 300 }.to_json, headers: json

      expect(Order.sole.utm_source).to eq("newsletter")
      expect(Order.sole.utm_campaign.length).to eq(255)
    end

    it "responde 404 para produto não publicado ou inexistente" do
      draft = create(:product)

      post "/checkout/paypal", params: { product_id: draft.id }.to_json, headers: json
      expect(response).to have_http_status(:not_found)
      post "/checkout/paypal", params: { product_id: "nope" }.to_json, headers: json
      expect(response).to have_http_status(:not_found)
      expect(Order.count).to eq(0)
    end

    it "funciona sem token CSRF e ainda lê os cookies de atribuição (LP cacheada)" do
      stub_paypal_create_order
      cookies["lo_attr"] = { utm_source: "facebook" }.to_json
      cookies["_fbp"] = "fb.1.1.1"

      with_forgery_protection do
        post "/checkout/paypal", params: { product_id: product.id }.to_json, headers: json
      end

      expect(response).to have_http_status(:created)
      expect(Order.sole).to have_attributes(utm_source: "facebook", fbp: "fb.1.1.1")
    end

    it "devolve 503 quando o PayPal está fora e 422 em erro permanente, sem deixar o pedido paid" do
      stub_paypal_create_order(status: 503, body: { name: "SERVICE_UNAVAILABLE" })
      post "/checkout/paypal", params: { product_id: product.id }.to_json, headers: json
      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body["error"]).to include("temporarily")

      stub_paypal_create_order(status: 422, body: { name: "UNPROCESSABLE_ENTITY", details: [ { issue: "X" } ] })
      post "/checkout/paypal", params: { product_id: product.id }.to_json, headers: json
      expect(response).to have_http_status(:unprocessable_content)
      expect(Order.where(status: "paid").count).to eq(0)
    end

    it "limita a 20 requisições por minuto por IP (T26)" do
      stub_paypal_create_order
      20.times { post "/checkout/paypal", params: { product_id: product.id }.to_json, headers: json }
      expect(response).to have_http_status(:created)

      post "/checkout/paypal", params: { product_id: product.id }.to_json, headers: json
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "POST /checkout/paypal/capture" do
    let!(:order) { create(:order, product:, paypal_order_id: "ORD-CAP") }

    it "captura COMPLETED → paid com Client e capture id (T01)" do
      stub_paypal_capture("ORD-CAP")

      post "/checkout/paypal/capture", params: { paypal_order_id: "ORD-CAP" }.to_json, headers: json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("status" => "completed", "order_id" => order.id)
      expect(order.reload).to be_paid
      expect(order.paypal_capture_id).to eq("3C679366HH908993F")
      expect(order.client.email).to eq("buyer@example.com")
      expect(order.download_token).to be_active
      expect(response.parsed_body["thank_you_url"]).to eq("http://www.example.com/thank-you/#{order.id}")
      expect(response.body).not_to include(order.download_token.token) # o link só vai por email/WhatsApp
    end

    it "é idempotente: segunda chamada devolve o mesmo resultado sem chamar o PayPal (T22)" do
      capture = stub_paypal_capture("ORD-CAP")
      post "/checkout/paypal/capture", params: { paypal_order_id: "ORD-CAP" }.to_json, headers: json
      first = response.parsed_body

      post "/checkout/paypal/capture", params: { paypal_order_id: "ORD-CAP" }.to_json, headers: json

      expect(response.parsed_body).to eq(first)
      expect(capture).to have_been_requested.once
      expect(Client.count).to eq(1)
    end

    it "trata ORDER_ALREADY_CAPTURED como sucesso (T17)" do
      stub_paypal_capture_error("ORD-CAP", issue: "ORDER_ALREADY_CAPTURED")
      stub_paypal_get_order("ORD-CAP", capture_id: "CAP-OLD")

      post "/checkout/paypal/capture", params: { paypal_order_id: "ORD-CAP" }.to_json, headers: json

      expect(response).to have_http_status(:ok)
      expect(order.reload).to be_paid
      expect(order.paypal_capture_id).to eq("CAP-OLD")
    end

    it "PENDING mantém o pedido pending e guarda o capture id e o motivo (T16)" do
      body = capture_body("ORD-CAP", status: "PENDING", capture_id: "CAP-PEND", payer: default_payer)
      body[:purchase_units][0][:payments][:captures][0][:status_details] = { reason: "RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION" }
      stub_paypal_capture("ORD-CAP", body:)

      post "/checkout/paypal/capture", params: { paypal_order_id: "ORD-CAP" }.to_json, headers: json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("pending")
      expect(order.reload).to be_pending
      expect(order.paypal_capture_id).to eq("CAP-PEND")
      expect(order.pending_reason).to eq("RECEIVING_PREFERENCE_MANDATES_MANUAL_ACTION")
      expect(order.download_token).not_to be_active # nasce inativo; o webhook o ativa ao confirmar
      expect(response.parsed_body["thank_you_url"]).to include("/thank-you/#{order.id}")
    end

    it "DECLINED → failed com 422" do
      stub_paypal_capture("ORD-CAP", status: "DECLINED")

      post "/checkout/paypal/capture", params: { paypal_order_id: "ORD-CAP" }.to_json, headers: json

      expect(response).to have_http_status(:unprocessable_content)
      expect(order.reload).to be_failed
    end

    it "responde 404 para paypal_order_id desconhecido" do
      post "/checkout/paypal/capture", params: { paypal_order_id: "NOPE" }.to_json, headers: json

      expect(response).to have_http_status(:not_found)
    end
  end
end
