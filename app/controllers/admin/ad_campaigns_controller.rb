module Admin
  # Meta Ads (spec 16): campanhas vistas pelo sync do Insights e o vínculo de cada uma a um produto. Duas
  # portas para o mesmo vínculo — a tela Meta Ads (index/update, seletor por campanha) e o show do produto
  # (create/destroy aninhados: vincular uma campanha ainda sem produto ou desvincular). Nome e id vêm da Meta.
  class AdCampaignsController < BaseController
    before_action :set_product, only: %i[create destroy]

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

    def create
      campaign = AdCampaign.unassigned.find_by(id: params[:ad_campaign_id])

      if campaign
        campaign.update!(product: @product)
        redirect_to admin_product_path(@product), status: :see_other, notice: "Campanha “#{campaign.name}” vinculada a este produto."
      else
        redirect_to admin_product_path(@product), status: :see_other, alert: "Escolha uma campanha que ainda não tenha produto."
      end
    end

    def destroy
      campaign = @product.ad_campaigns.find(params[:id])
      campaign.update!(product: nil)
      redirect_to admin_product_path(@product), status: :see_other, notice: "Campanha “#{campaign.name}” desvinculada deste produto."
    end

    private
      def set_product
        @product = Product.find_by!(slug: params[:product_id])
      end
  end
end
