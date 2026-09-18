FactoryBot.define do
  factory :download_token do
    association :order, :paid

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :revoked do
      revoked_at { 1.hour.ago }
    end

    trait :limit_reached do
      max_downloads { 3 }
      download_count { 3 }
    end

    trait :unpaid do
      association :order, :pending
    end
  end
end
