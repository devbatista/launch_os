FactoryBot.define do
  factory :order do
    association :product, :published
    amount_cents { product.price_cents }
    currency { product.currency }
    status { "pending" }
    sequence(:paypal_order_id) { |n| "PAYPAL-ORDER-#{n}" }
    ip_address { "203.0.113.10" }
    user_agent { "Mozilla/5.0 (iPhone)" }

    trait :pending do
      status { "pending" }
    end

    trait :paid do
      status { "paid" }
      paid_at { Time.current }
      client
      payer_email { client.email }
      payer_name { client.name }
      sequence(:paypal_capture_id) { |n| "PAYPAL-CAPTURE-#{n}" }
    end

    trait :failed do
      status { "failed" }
      failed_at { Time.current }
    end

    trait :refunded do
      paid
      status { "refunded" }
      refunded_at { Time.current }
    end

    trait :disputed do
      paid
      status { "disputed" }
      disputed_at { Time.current }
    end

    trait :with_attribution do
      utm_source { "facebook" }
      utm_medium { "paid" }
      utm_campaign { "launch-1" }
      utm_content { "video-a" }
      utm_term { "focus" }
      fbclid { "IwAR123" }
      fbp { "fb.1.1700000000.123456" }
      fbc { "fb.1.1700000000.IwAR123" }
      landing_path { "/21-day-procrastination-reset" }
      referrer { "https://l.facebook.com/" }
    end

    trait :with_whatsapp_opt_in do
      phone { "+14155552671" }
      whatsapp_opt_in { true }
    end
  end
end
