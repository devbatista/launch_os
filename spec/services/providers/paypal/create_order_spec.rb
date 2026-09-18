require "rails_helper"

RSpec.describe Providers::Paypal::CreateOrder, :paypal do
  before { stub_paypal_token }

  describe ".call" do
    it "monta o pedido com o preço do Order (nunca do cliente) e grava paypal_order_id" do
      product = create(:product, :published, name: "Focus Reset", price_cents: 1490, slug: "focus")
      order = create(:order, product:, paypal_order_id: nil)
      stub = stub_request(:post, "#{PaypalStubs::BASE}/v2/checkout/orders")
        .with(headers: { "PayPal-Request-Id" => order.id }) { |req|
          body = JSON.parse(req.body)
          unit = body["purchase_units"][0]
          body["intent"] == "CAPTURE" && unit["custom_id"] == order.id && unit["reference_id"] == order.id &&
            unit["amount"] == { "currency_code" => "USD", "value" => "14.90" } && unit["description"] == "Focus Reset" &&
            body.dig("payment_source", "paypal", "experience_context", "shipping_preference") == "NO_SHIPPING" &&
            body.dig("payment_source", "paypal", "experience_context", "return_url").include?("/focus")
        }
        .to_return(status: 201, body: { id: "ORD-NEW" }.to_json, headers: { "Content-Type" => "application/json" })

      described_class.call(order)

      expect(stub).to have_been_requested
      expect(order.reload.paypal_order_id).to eq("ORD-NEW")
    end
  end

  describe Providers::Paypal::CaptureOrder do # rubocop:disable RSpec/DescribeClass
    let(:order) { create(:order, paypal_order_id: "ORD-CAP") }

    it "captura e devolve a resposta" do
      stub_paypal_capture("ORD-CAP")

      expect(described_class.call(order).dig("purchase_units", 0, "payments", "captures", 0, "id")).to eq("3C679366HH908993F")
    end

    it "trata ORDER_ALREADY_CAPTURED como sucesso buscando o pedido" do
      stub_paypal_capture_error("ORD-CAP", issue: "ORDER_ALREADY_CAPTURED")
      get = stub_paypal_get_order("ORD-CAP", capture_id: "CAP-OLD")

      expect(described_class.call(order).dig("purchase_units", 0, "payments", "captures", 0, "id")).to eq("CAP-OLD")
      expect(get).to have_been_requested
    end

    it "propaga outros erros permanentes" do
      stub_paypal_capture_error("ORD-CAP", issue: "ORDER_NOT_APPROVED")

      expect { described_class.call(order) }.to raise_error(Providers::PermanentError)
    end
  end
end
