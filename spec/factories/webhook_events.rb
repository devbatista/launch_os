FactoryBot.define do
  factory :webhook_event do
    provider { "paypal" }
    sequence(:external_id) { |n| "WH-EVT-#{n}" }
    event_type { "PAYMENT.CAPTURE.COMPLETED" }
    signature_valid { true }
    status { "received" }
    payload { { "id" => external_id, "event_type" => event_type, "resource" => {} } }

    # Evento de capture completo apontando para o pedido pelo custom_id.
    trait :capture_completed do
      transient { order { create(:order) } }
      payload do
        { "id" => external_id, "event_type" => "PAYMENT.CAPTURE.COMPLETED",
          "resource" => { "id" => "CAP-WH-1", "status" => "COMPLETED", "custom_id" => order.id,
                          "supplementary_data" => { "related_ids" => { "order_id" => order.paypal_order_id } } } }
      end
    end
  end
end
