# Métricas de um anúncio da Meta em um dia (spec 16, Insights). Gravado só por MetaAds::SyncInsights, via
# upsert por (meta_ad_id, date). `ad_name` = `utm_content` dos pedidos (convenção do briefing de criativos).
class AdInsight < ApplicationRecord
  validates :date, :meta_ad_id, :ad_name, :currency, presence: true
  validates :meta_ad_id, uniqueness: { scope: :date }
  validates :spend_cents, :impressions, :link_clicks, :landing_page_views, :initiate_checkouts, :purchases,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :between, ->(dates) { where(date: dates) }
end
