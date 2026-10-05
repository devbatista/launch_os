FactoryBot.define do
  factory :ad_insight do
    date { Date.current }
    sequence(:meta_ad_id) { |n| "1200000000000#{n.to_s.rjust(5, '0')}" }
    ad_name { "method-01" }
    meta_campaign_id { "120000000000000000" }
    campaign_name { "Reset | Vendas | DevBatista | Outubro/2026" }
    spend_cents { 2540 }
    currency { "BRL" }
    impressions { 300 }
    link_clicks { 4 }
    landing_page_views { 3 }
    initiate_checkouts { 0 }
    purchases { 0 }
  end
end
