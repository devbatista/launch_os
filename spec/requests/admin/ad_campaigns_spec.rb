require "rails_helper"

# Campanhas Meta (spec 16): lista as campanhas do sync e o vínculo manual com o produto.
RSpec.describe "Admin ad campaigns" do
  let(:product) { create(:product, :published, name: "21-Day Procrastination Reset") }
  let!(:campaign) { create(:ad_campaign, meta_campaign_id: "C1", name: "Reset | Vendas") }

  it "redireciona para o login sem sessão" do
    get admin_ad_campaigns_path
    expect(response).to redirect_to(admin_login_path)

    patch admin_ad_campaign_path(campaign), params: { ad_campaign: { product_id: product.id } }
    expect(response).to redirect_to(admin_login_path)
    expect(campaign.reload.product_id).to be_nil
  end

  context "com sessão" do
    before { sign_in_admin }

    it "lista campanhas com gasto total, último dia e aviso das pendentes" do
      create(:ad_insight, meta_campaign_id: "C1", date: Date.new(2026, 10, 3), spend_cents: 2482)
      create(:ad_insight, meta_campaign_id: "C1", date: Date.new(2026, 10, 4), spend_cents: 4010)

      get admin_ad_campaigns_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Campanhas Meta", "Reset | Vendas", "C1", "BRL 64.92", "04/10/2026", "1 campanha sem produto")
    end

    it "vincula e desvincula o produto" do
      patch admin_ad_campaign_path(campaign), params: { ad_campaign: { product_id: product.id } }

      expect(response).to redirect_to(admin_ad_campaigns_path)
      expect(flash[:notice]).to eq("Campanha “Reset | Vendas” vinculada a 21-Day Procrastination Reset.")
      expect(campaign.reload.product).to eq(product)

      patch admin_ad_campaign_path(campaign), params: { ad_campaign: { product_id: "" } }

      expect(flash[:notice]).to eq("Campanha “Reset | Vendas” ficou sem produto.")
      expect(campaign.reload.product_id).to be_nil
    end

    it "recusa produto inexistente sem alterar o vínculo" do
      campaign.update!(product:)

      patch admin_ad_campaign_path(campaign), params: { ad_campaign: { product_id: SecureRandom.uuid } }

      expect(flash[:alert]).to eq("Produto não encontrado.")
      expect(campaign.reload.product).to eq(product)
    end
  end
end
