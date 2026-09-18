FactoryBot.define do
  factory :message_log do
    association :order, :paid
    client { order.client }
    channel { "email" }
    template { "order_delivery" }
    recipient { order.client.email }
    status { "queued" }

    trait :sent do
      status { "sent" }
      sent_at { Time.current }
      sequence(:provider_message_id) { |n| "<ses-#{n}@email.amazonses.com>" }
    end

    trait :failed do
      status { "failed" }
      failed_at { Time.current }
      attempts { 1 }
      error_message { "SES MessageRejected: Email address is not verified." }
    end

    trait :whatsapp do
      channel { "whatsapp" }
      recipient { "+14155552671" }
    end
  end
end
