# Stubs WebMock da REST API do PayPal (sandbox) — nenhuma chamada real nos specs (spec 07).
module PaypalStubs
  BASE = "https://api-m.sandbox.paypal.com"

  def stub_paypal_token(token: "TEST-TOKEN", expires_in: 32_400)
    stub_request(:post, "#{BASE}/v1/oauth2/token")
      .with(body: "grant_type=client_credentials", basic_auth: [ ENV.fetch("PAYPAL_CLIENT_ID", "test-id"), ENV.fetch("PAYPAL_CLIENT_SECRET", "test-secret") ])
      .to_return(status: 200, body: { access_token: token, token_type: "Bearer", expires_in: }.to_json, headers: json_headers)
  end

  # Sem `id:` cada chamada devolve um id novo (paypal_order_id é único no Order).
  def stub_paypal_create_order(id: nil, status: 200, body: nil)
    stub_request(:post, "#{BASE}/v2/checkout/orders")
      .to_return { { status:, body: (body || { id: id || "ORD-#{SecureRandom.hex(6)}", status: "CREATED" }).to_json, headers: json_headers } }
  end

  def stub_paypal_capture(paypal_order_id, status: "COMPLETED", capture_id: "3C679366HH908993F", payer: default_payer, http_status: 200, body: nil)
    stub_request(:post, "#{BASE}/v2/checkout/orders/#{paypal_order_id}/capture")
      .to_return(status: http_status, body: (body || capture_body(paypal_order_id, status:, capture_id:, payer:)).to_json, headers: json_headers)
  end

  def stub_paypal_capture_error(paypal_order_id, issue:, http_status: 422)
    stub_request(:post, "#{BASE}/v2/checkout/orders/#{paypal_order_id}/capture")
      .to_return(status: http_status, body: { name: "UNPROCESSABLE_ENTITY", details: [ { issue: } ], message: "The requested action could not be performed." }.to_json, headers: json_headers)
  end

  def stub_paypal_get_order(paypal_order_id, status: "COMPLETED", capture_id: "3C679366HH908993F", payer: default_payer)
    stub_request(:get, "#{BASE}/v2/checkout/orders/#{paypal_order_id}")
      .to_return(status: 200, body: capture_body(paypal_order_id, status:, capture_id:, payer:).to_json, headers: json_headers)
  end

  def stub_paypal_verify_webhook(valid: true)
    stub_request(:post, "#{BASE}/v1/notifications/verify-webhook-signature")
      .to_return(status: 200, body: { verification_status: valid ? "SUCCESS" : "FAILURE" }.to_json, headers: json_headers)
  end

  def default_payer
    { "email_address" => "buyer@example.com", "payer_id" => "PAYER123",
      "name" => { "given_name" => "Jane", "surname" => "Buyer" }, "address" => { "country_code" => "US" } }
  end

  def capture_body(paypal_order_id, status:, capture_id:, payer:)
    {
      id: paypal_order_id, status: (status == "COMPLETED" ? "COMPLETED" : "APPROVED"), payer:,
      purchase_units: [ { reference_id: "ref", payments: { captures: [ { id: capture_id, status:, amount: { currency_code: "USD", value: "14.90" } } ] } } ]
    }
  end

  def json_headers = { "Content-Type" => "application/json" }
end

RSpec.configure do |config|
  config.include PaypalStubs

  # Credenciais de teste para o Client ler de ENV sem depender do .env de quem roda a suíte.
  config.before(:each, :paypal) do
    stub_const("ENV", ENV.to_h.merge("PAYPAL_ENV" => "sandbox", "PAYPAL_CLIENT_ID" => "test-id",
                                     "PAYPAL_CLIENT_SECRET" => "test-secret", "PAYPAL_WEBHOOK_ID" => "WH-TEST"))
  end
end
