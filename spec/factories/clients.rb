FactoryBot.define do
  factory :client do
    sequence(:email) { |n| "buyer#{n}@example.com" }
    name { "Jane Buyer" }
    country { "US" }

    trait :with_whatsapp_opt_in do
      phone { "+14155552671" }
      whatsapp_opt_in { true }
      whatsapp_opt_in_at { Time.current }
      whatsapp_opt_in_text { I18n.t("checkout.whatsapp_opt_in", locale: :en) }
    end

    trait :opted_out do
      with_whatsapp_opt_in
      whatsapp_opt_in { false }
      whatsapp_opt_out_at { Time.current }
    end
  end
end
