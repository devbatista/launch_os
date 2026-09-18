require "rails_helper"

# POST /webhooks/paypal (spec 07): assinatura verificada, evento gravado uma vez, job enfileirado, 2xx rápido.
RSpec.describe "Webhooks PayPal", :paypal do
  include ActiveJob::TestHelper

  let(:order) { create(:order) }

  before { stub_paypal_token }

  it "grava o evento com assinatura válida, enfileira o job e responde 200 (T02)" do
    stub_paypal_verify_webhook(valid: true)
    event = paypal_event("PAYMENT.CAPTURE.COMPLETED", id: "WH-OK", resource: capture_resource(order))

    expect { post_paypal_webhook(event) }.to have_enqueued_job(ProcessPaypalWebhookJob).on_queue("webhooks")

    expect(response).to have_http_status(:ok)
    we = WebhookEvent.sole
    expect(we).to have_attributes(provider: "paypal", external_id: "WH-OK", event_type: "PAYMENT.CAPTURE.COMPLETED", signature_valid: true, status: "received")
    expect(we.payload["resource"]["custom_id"]).to eq(order.id)
    expect(we.headers.keys).to match_array(PaypalWebhookHelpers::SIGNATURE.keys)
    expect(order.reload).to be_pending # o processamento é no job
  end

  it "responde 400 com assinatura inválida, grava como ignored e não enfileira nada (T03)" do
    stub_paypal_verify_webhook(valid: false)
    event = paypal_event("PAYMENT.CAPTURE.COMPLETED", id: "WH-BAD", resource: capture_resource(order))

    expect { post_paypal_webhook(event) }.not_to have_enqueued_job

    expect(response).to have_http_status(:bad_request)
    expect(WebhookEvent.sole).to have_attributes(signature_valid: false, status: "ignored", error: "invalid signature")
    expect(order.reload).to be_pending
  end

  it "responde 400 sem os headers de assinatura, sem chamar a API" do
    verify = stub_paypal_verify_webhook(valid: true)

    post_paypal_webhook(paypal_event("PAYMENT.CAPTURE.COMPLETED", id: "WH-NOHDR"), headers: {})

    expect(response).to have_http_status(:bad_request)
    expect(verify).not_to have_been_requested
    expect(WebhookEvent.sole.signature_valid).to be(false)
  end

  it "é idempotente: o mesmo evento 2× gera um único WebhookEvent e um único job (T05)" do
    stub_paypal_verify_webhook(valid: true)
    event = paypal_event("PAYMENT.CAPTURE.COMPLETED", id: "WH-DUP", resource: capture_resource(order))

    post_paypal_webhook(event)
    perform_enqueued_jobs
    expect(order.reload).to be_paid

    expect { post_paypal_webhook(event) }.not_to have_enqueued_job
    expect(response).to have_http_status(:ok)
    expect(WebhookEvent.count).to eq(1)
    expect(WebhookEvent.sole).to be_processed
  end

  it "responde 400 para corpo inválido ou sem id/event_type" do
    post "/webhooks/paypal", params: "not json", headers: PaypalWebhookHelpers::SIGNATURE.merge("CONTENT_TYPE" => "application/json")
    expect(response).to have_http_status(:bad_request)

    post_paypal_webhook({ "foo" => "bar" })
    expect(response).to have_http_status(:bad_request)
    expect(WebhookEvent.count).to eq(0)
  end

  it "não exige sessão nem token CSRF" do
    stub_paypal_verify_webhook(valid: true)
    ActionController::Base.allow_forgery_protection = true

    post_paypal_webhook(paypal_event("PAYMENT.CAPTURE.PENDING", id: "WH-CSRF", resource: capture_resource(order, status: "PENDING")))

    expect(response).to have_http_status(:ok)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "pula a verificação só em development com PAYPAL_WEBHOOK_SKIP_VERIFY" do
    verify = stub_paypal_verify_webhook(valid: false)
    stub_const("ENV", ENV.to_h.merge("PAYPAL_WEBHOOK_SKIP_VERIFY" => "true"))
    allow(Rails.env).to receive(:development?).and_return(true)

    post_paypal_webhook(paypal_event("PAYMENT.CAPTURE.PENDING", id: "WH-SKIP", resource: capture_resource(order, status: "PENDING")), headers: {})

    expect(response).to have_http_status(:ok)
    expect(verify).not_to have_been_requested
  end
end
