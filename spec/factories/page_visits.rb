FactoryBot.define do
  factory :page_visit do
    association :product, :published
    path { "/#{product.slug}" }
    user_agent { "Mozilla/5.0 (iPhone)" }
    sequence(:visitor_id) { |n| "visitor-#{n}" }
    ip_hash { "a" * 64 }

    trait :from_campaign do
      utm_source { "facebook" }
      utm_medium { "paid" }
      utm_campaign { "launch-1" }
      utm_content { "video-a" }
      fbclid { "IwAR123" }
      referrer { "https://l.facebook.com/" }
    end
  end
end
