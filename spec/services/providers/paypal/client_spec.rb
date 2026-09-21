require "rails_helper"

# T28 (spec 15)
RSpec.describe Providers::Paypal::Client, :paypal do
  subject(:client) { described_class.new }

  describe "#access_token" do
    it "pede o token com client_credentials e cacheia por expires_in - 60 s" do
      stub = stub_paypal_token(token: "T1", expires_in: 3600)

      expect(client.access_token).to eq("T1")
      expect(client.access_token).to eq("T1")
      expect(stub).to have_been_requested.once

      travel 3600 - 60 + 1 do
        stub_paypal_token(token: "T2")
        expect(client.access_token).to eq("T2")
      end
    end

    it "levanta PermanentError com credenciais inválidas" do
      stub_request(:post, "#{PaypalStubs::BASE}/v1/oauth2/token")
        .to_return(status: 401, body: { error: "invalid_client", error_description: "Client Authentication failed" }.to_json, headers: json_headers)

      expect { client.access_token }.to raise_error(Providers::PermanentError, /invalid_client/)
    end
  end

  describe "#create_order" do
    before { stub_paypal_token }

    it "envia Bearer, PayPal-Request-Id e o corpo em JSON" do
      stub = stub_request(:post, "#{PaypalStubs::BASE}/v2/checkout/orders")
        .with(headers: { "Authorization" => "Bearer TEST-TOKEN", "PayPal-Request-Id" => "req-1", "Content-Type" => "application/json" },
              body: { intent: "CAPTURE" }.to_json)
        .to_return(status: 201, body: { id: "ORD-1" }.to_json, headers: json_headers)

      expect(client.create_order({ intent: "CAPTURE" }, request_id: "req-1")).to eq("id" => "ORD-1")
      expect(stub).to have_been_requested
    end

    it "mapeia 4xx para ApiError com name/details" do
      stub_paypal_create_order(status: 422, body: { name: "UNPROCESSABLE_ENTITY", details: [ { issue: "CURRENCY_NOT_SUPPORTED" } ], message: "nope" })

      expect { client.create_order({}, request_id: "r") }.to raise_error(described_class::ApiError) { |e|
        expect(e).to be_a(Providers::PermanentError)
        expect(e.status).to eq(422)
        expect(e.error_name).to eq("UNPROCESSABLE_ENTITY")
        expect(e).to be_issue("CURRENCY_NOT_SUPPORTED")
      }
    end

    it "mapeia 5xx, 429 e timeout para TransientError" do
      stub_paypal_create_order(status: 503, body: { name: "SERVICE_UNAVAILABLE" })
      expect { client.create_order({}, request_id: "r") }.to raise_error(Providers::TransientError)

      stub_paypal_create_order(status: 429, body: { name: "RATE_LIMIT_REACHED" })
      expect { client.create_order({}, request_id: "r") }.to raise_error(Providers::TransientError)

      stub_request(:post, "#{PaypalStubs::BASE}/v2/checkout/orders").to_timeout
      expect { client.create_order({}, request_id: "r") }.to raise_error(Providers::TransientError, /unreachable/)
    end
  end

  describe "#capture_order e #get_order" do
    before { stub_paypal_token }

    it "captura com request id próprio e lê o pedido" do
      capture = stub_paypal_capture("ORD-9")
      get = stub_paypal_get_order("ORD-9")

      expect(client.capture_order("ORD-9", request_id: "capture-x").dig("purchase_units", 0, "payments", "captures", 0, "status")).to eq("COMPLETED")
      expect(client.get_order("ORD-9")["id"]).to eq("ORD-9")
      expect(capture.with(headers: { "PayPal-Request-Id" => "capture-x" })).to have_been_requested
      expect(get).to have_been_requested
    end
  end

  describe "#verify_webhook_signature" do
    before { stub_paypal_token }

    it "envia os headers PAYPAL-*, o webhook_id e o evento parseado; true só com SUCCESS" do
      body = { id: "WH-EVT-1", event_type: "PAYMENT.CAPTURE.COMPLETED" }.to_json
      headers = { "PAYPAL-AUTH-ALGO" => "SHA256withRSA", "PAYPAL-CERT-URL" => "https://api.paypal.com/cert", "PAYPAL-TRANSMISSION-ID" => "t1",
                  "PAYPAL-TRANSMISSION-SIG" => "sig", "PAYPAL-TRANSMISSION-TIME" => "2026-09-17T00:00:00Z" }
      stub = stub_request(:post, "#{PaypalStubs::BASE}/v1/notifications/verify-webhook-signature")
        .with(body: hash_including("webhook_id" => "WH-TEST", "transmission_id" => "t1", "webhook_event" => { "id" => "WH-EVT-1", "event_type" => "PAYMENT.CAPTURE.COMPLETED" }))
        .to_return(status: 200, body: { verification_status: "SUCCESS" }.to_json, headers: json_headers)

      expect(client.verify_webhook_signature(headers:, body:)).to be(true)
      expect(stub).to have_been_requested

      stub_paypal_verify_webhook(valid: false)
      expect(client.verify_webhook_signature(headers:, body:)).to be(false)
    end
  end

  describe "#update_webhook_url" do
    before { stub_paypal_token }

    it "faz PATCH replace em /url no webhook configurado" do
      stub = stub_request(:patch, "#{PaypalStubs::BASE}/v1/notifications/webhooks/WH-TEST")
        .with(body: [ { op: "replace", path: "/url", value: "https://x.trycloudflare.com/webhooks/paypal" } ].to_json)
        .to_return(status: 200, body: { id: "WH-TEST", url: "https://x.trycloudflare.com/webhooks/paypal" }.to_json, headers: json_headers)

      expect(client.update_webhook_url("https://x.trycloudflare.com/webhooks/paypal")["url"]).to end_with("/webhooks/paypal")
      expect(stub).to have_been_requested
    end
  end

  describe "#list_webhooks / #create_webhook" do
    before { stub_paypal_token }

    it "lista os webhooks do app" do
      stub_request(:get, "#{PaypalStubs::BASE}/v1/notifications/webhooks")
        .to_return(status: 200, body: { webhooks: [ { id: "WH-1", url: "https://a/webhooks/paypal", event_types: [] } ] }.to_json, headers: json_headers)

      expect(client.list_webhooks.map { |w| w["id"] }).to eq([ "WH-1" ])
    end

    it "cria um webhook com os 9 eventos tratados pelo job" do
      stub = stub_request(:post, "#{PaypalStubs::BASE}/v1/notifications/webhooks")
        .with { |req| body = JSON.parse(req.body); body["url"] == "https://www.devbatista.online/webhooks/paypal" && body["event_types"].map { |e| e["name"] } == Providers::Paypal::Client::WEBHOOK_EVENT_TYPES }
        .to_return(status: 201, body: { id: "WH-NEW", url: "https://www.devbatista.online/webhooks/paypal", event_types: [] }.to_json, headers: json_headers)

      expect(client.create_webhook("https://www.devbatista.online/webhooks/paypal")["id"]).to eq("WH-NEW")
      expect(stub).to have_been_requested
    end
  end

  it "rejeita PAYPAL_ENV desconhecido" do
    expect { described_class.new(env: "prod") }.to raise_error(ArgumentError, /sandbox or live/)
  end
end
