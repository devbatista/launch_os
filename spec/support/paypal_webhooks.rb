# Payloads e headers de webhook do PayPal para request/job specs.
module PaypalWebhookHelpers
  SIGNATURE = { "PAYPAL-AUTH-ALGO" => "SHA256withRSA", "PAYPAL-CERT-URL" => "https://api.sandbox.paypal.com/v1/notifications/certs/CERT-1",
                "PAYPAL-TRANSMISSION-ID" => "tid-1", "PAYPAL-TRANSMISSION-SIG" => "sig==", "PAYPAL-TRANSMISSION-TIME" => "2026-09-17T12:00:00Z" }.freeze

  def paypal_event(type, id: "WH-#{SecureRandom.hex(4)}", resource: {})
    { "id" => id, "event_type" => type, "create_time" => "2026-09-17T12:00:00Z", "resource_type" => "capture", "resource" => resource }
  end

  def capture_resource(order, id: "CAP-1", status: "COMPLETED", extra: {})
    { "id" => id, "status" => status, "custom_id" => order.id, "amount" => { "currency_code" => "USD", "value" => "14.90" },
      "supplementary_data" => { "related_ids" => { "order_id" => order.paypal_order_id } } }.merge(extra)
  end

  def post_paypal_webhook(event, headers: SIGNATURE)
    post "/webhooks/paypal", params: event.to_json, headers: headers.merge("CONTENT_TYPE" => "application/json")
  end
end

RSpec.configure { |config| config.include PaypalWebhookHelpers }
