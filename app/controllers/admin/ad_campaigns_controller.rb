module Admin
  # Campanhas da Meta vistas pelo sync do Insights (spec 16) e o vínculo de cada uma a um produto — é o que
  # separa gasto, CAC e ROAS por produto no dashboard. Só o vínculo é editável; nome e id vêm da Meta.
  class AdCampaignsController < BaseController
    def index
      @campaigns = AdCampaign.includes(:product).recent
      @spend = AdInsight.group(:meta_campaign_id).sum(:spend_cents)
      @last_day = AdInsight.where("spend_cents > 0").group(:meta_campaign_id).maximum(:date)
      @currency = AdInsight.pick(:currency) || "BRL"
      @products = Product.order(:name)
    end

    def update
      campaign = AdCampaign.find(params[:id])
      product_id = params.dig(:ad_campaign, :product_id).presence
      product = product_id && Product.find_by(id: product_id)

      if product_id && product.nil?
        redirect_to admin_ad_campaigns_path, status: :see_other, alert: "Produto não encontrado."
      else
        campaign.update!(product:)
        redirect_to admin_ad_campaigns_path, status: :see_other,
                    notice: product ? "Campanha “#{campaign.name}” vinculada a #{product.name}." : "Campanha “#{campaign.name}” ficou sem produto."
      end
    end
  end
end
