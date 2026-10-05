FactoryBot.define do
  factory :ad_campaign do
    sequence(:meta_campaign_id) { |n| "1202500000000#{n.to_s.rjust(5, '0')}" }
    name { "Reset | Vendas | DevBatista | Out/2026" }
    product { nil }
  end
end
