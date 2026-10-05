# Métricas de um anúncio da Meta em um dia (spec 16, Insights). Gravado só por MetaAds::SyncInsights, via
# upsert por (meta_ad_id, date). `ad_name` = `utm_content` dos pedidos (convenção do briefing de criativos).
class AdInsight < ApplicationRecord
  # O produto vem da campanha (vínculo manual no admin), não do anúncio.
  belongs_to :ad_campaign, primary_key: :meta_campaign_id, foreign_key: :meta_campaign_id, optional: true, inverse_of: :ad_insights

  validates :date, :meta_ad_id, :ad_name, :currency, presence: true
  validates :meta_ad_id, uniqueness: { scope: :date }
  validates :spend_cents, :impressions, :link_clicks, :landing_page_views, :initiate_checkouts, :purchases,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :between, ->(dates) { where(date: dates) }
end
