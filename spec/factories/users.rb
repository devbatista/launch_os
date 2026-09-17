FactoryBot.define do
  factory :user do
    name { "Admin" }
    sequence(:email_address) { |n| "admin#{n}@example.com" }
    password { "correct-horse-battery" }

    trait :locked do
      failed_attempts { User::MAX_FAILED_ATTEMPTS }
      locked_at { Time.current }
    end
  end
end
