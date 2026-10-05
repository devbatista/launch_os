# Campanha da Meta (spec 16). Criada/renomeada pelo MetaAds::SyncInsights a partir do Insights; o vínculo
# com o produto é manual, no admin (Campanhas Meta). Sem produto, o gasto da campanha não entra em nenhum
# produto do dashboard e aparece como pendência.
class AdCampaign < ApplicationRecord
  belongs_to :product, optional: true
  has_many :ad_insights, primary_key: :meta_campaign_id, foreign_key: :meta_campaign_id, inverse_of: :ad_campaign

  validates :meta_campaign_id, presence: true, uniqueness: true
  validates :name, presence: true

  scope :assigned, -> { where.not(product_id: nil) }
  scope :unassigned, -> { where(product_id: nil) }
  scope :recent, -> { order(created_at: :desc) }
end
