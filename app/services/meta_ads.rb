# Integração com o Meta Ads pela Marketing API (spec 16). Por ora só Insights (leitura); criação de
# campanhas fica para depois. Desligada enquanto token e conta não estão configurados.
module MetaAds
  # Fuso da conta de anúncios `DevBatista` (checklist 0.2): os dias do Insights são deste fuso.
  TIME_ZONE = "America/Sao_Paulo".freeze

  def self.insights_enabled? = ENV["META_ACCESS_TOKEN"].present? && ENV["META_AD_ACCOUNT_ID"].present?
end
