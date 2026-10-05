require "rails_helper"

# Meta Ads (spec 16): campanhas do sync e o vínculo com o produto — pela tela Meta Ads e pelo show do produto.
RSpec.describe "Admin ad campaigns" do
  let(:product) { create(:product, :published, name: "21-Day Procrastination Reset") }
  let!(:campaign) { create(:ad_campaign, meta_campaign_id: "C1", name: "Reset | Vendas") }

  it "redireciona para o login sem sessão" do
    get admin_ad_campaigns_path
    expect(response).to redirect_to(admin_login_path)

    patch admin_ad_campaign_path(campaign), params: { ad_campaign: { product_id: product.id } }
    expect(response).to redirect_to(admin_login_path)

    post admin_product_ad_campaigns_path(product), params: { ad_campaign_id: campaign.id }
    expect(response).to redirect_to(admin_login_path)
    expect(campaign.reload.product_id).to be_nil
  end

  context "com sessão" do
    before { sign_in_admin }

    describe "tela Meta Ads" do
      it "lista campanhas com gasto total, último dia e aviso das pendentes; sidebar com o item Meta Ads" do
        create(:ad_insight, meta_campaign_id: "C1", date: Date.new(2026, 10, 3), spend_cents: 2482)
        create(:ad_insight, meta_campaign_id: "C1", date: Date.new(2026, 10, 4), spend_cents: 4010)

        get admin_ad_campaigns_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Meta Ads", "Reset | Vendas", "C1", "BRL 64.92", "04/10/2026", "1 campanha sem produto")
        expect(response.body).not_to include("Campanhas Meta")
      end

      it "vincula e desvincula o produto pelo seletor" do
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

    describe "show do produto" do
      it "oferece as campanhas sem produto e vincula; depois mostra os números da campanha" do
        get admin_product_path(product)
        expect(response.body).to include("Meta Ads", "Nenhuma campanha vinculada", "Vincular campanha", "Reset | Vendas")

        post admin_product_ad_campaigns_path(product), params: { ad_campaign_id: campaign.id }

        expect(response).to redirect_to(admin_product_path(product))
        expect(flash[:notice]).to eq("Campanha “Reset | Vendas” vinculada a este produto.")
        expect(campaign.reload.product).to eq(product)

        create(:ad_insight, meta_campaign_id: "C1", ad_name: "method-01", date: Time.current.in_time_zone("America/Sao_Paulo").to_date,
                            spend_cents: 6210, impressions: 748, link_clicks: 10)
        get admin_product_path(product)

        expect(response.body).to include("Insights atualizado em", "Vida toda (desde", "Últimos 7 dias", "BRL 62.10", "1,34%", "method-01", "Desvincular")
      end

      it "não vincula campanha que já tem produto" do
        other = create(:product, :published, slug: "other")
        campaign.update!(product: other)

        post admin_product_ad_campaigns_path(product), params: { ad_campaign_id: campaign.id }

        expect(flash[:alert]).to eq("Escolha uma campanha que ainda não tenha produto.")
        expect(campaign.reload.product).to eq(other)
      end

      it "desvincula só campanha do próprio produto" do
        campaign.update!(product:)

        delete admin_product_ad_campaign_path(product, campaign)

        expect(response).to redirect_to(admin_product_path(product))
        expect(flash[:notice]).to eq("Campanha “Reset | Vendas” desvinculada deste produto.")
        expect(campaign.reload.product_id).to be_nil

        other_campaign = create(:ad_campaign, product: create(:product, :published, slug: "other"))
        delete admin_product_ad_campaign_path(product, other_campaign)
        expect(response).to have_http_status(:not_found)
        expect(other_campaign.reload.product_id).not_to be_nil
      end
    end
  end
end
