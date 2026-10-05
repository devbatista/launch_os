require "rails_helper"

RSpec.describe Admin::ProductAdsReport do
  subject(:report) { described_class.new(product) }

  let(:product) { create(:product, :published) }
  let(:today) { Date.new(2026, 10, 10) }

  around { |example| travel_to(Time.find_zone("America/Sao_Paulo").local(2026, 10, 10, 15)) { example.run } }

  def paid_order(day, **attrs)
    create(:order, :paid, product:, utm_source: "facebook", utm_content: "method-01",
                          created_at: Time.find_zone("America/Sao_Paulo").local(2026, 10, day, 10), **attrs)
  end

  it "sem campanha vinculada não tem dados e zera os números" do
    expect(report.campaigns).to be_empty
    expect(report.data?).to be(false)
    expect(report.lifetime).to include(spend_cents: 0, sales: 0, cac_cents: nil, roas: nil)
  end

  context "com campanha vinculada" do
    before do
      create(:ad_campaign, meta_campaign_id: "C1", product:)
      create(:ad_campaign, meta_campaign_id: "C-OUTRO", product: create(:product, :published, slug: "other"))
      create(:ad_insight, meta_campaign_id: "C1", meta_ad_id: "A1", ad_name: "method-01", date: Date.new(2026, 10, 2),
                          spend_cents: 1000, impressions: 300, link_clicks: 6, landing_page_views: 2)
      create(:ad_insight, meta_campaign_id: "C1", meta_ad_id: "A1", ad_name: "method-01", date: Date.new(2026, 10, 9),
                          spend_cents: 4000, impressions: 400, link_clicks: 4, landing_page_views: 3, purchases: 1)
      create(:ad_insight, meta_campaign_id: "C1", meta_ad_id: "A2", ad_name: "pain-01", date: Date.new(2026, 10, 9),
                          spend_cents: 1000, impressions: 100, link_clicks: 2, landing_page_views: 0)
      create(:ad_insight, meta_campaign_id: "C-OUTRO", meta_ad_id: "A9", ad_name: "other-01", date: Date.new(2026, 10, 9), spend_cents: 99_999)
    end

    it "soma só as campanhas do produto: vida toda desde o primeiro dia e últimos 7 dias" do
      paid_order(2, paypal_receivable_cents: 6860, paypal_receivable_currency: "BRL")
      paid_order(9, paypal_receivable_cents: 6860, paypal_receivable_currency: "BRL")
      create(:order, :pending, product:, utm_source: "facebook", utm_content: "pain-01")
      create(:order, :paid, product:, utm_source: nil) # orgânico: fora

      expect(report.first_date).to eq(Date.new(2026, 10, 2))
      expect(report.lifetime).to include(spend_cents: 6000, impressions: 800, link_clicks: 12, ctr: 1.5.to_d, landing_page_views: 5,
                                         meta_purchases: 1, checkouts: 3, sales: 2, cac_cents: 3000, roas: 2.29.to_d)
      expect(report.recent).to include(spend_cents: 5000, impressions: 500, link_clicks: 6, sales: 1, checkouts: 2, cac_cents: 5000, roas: 1.37.to_d)
    end

    it "ROAS fica nil enquanto algum pedido pago não tem o valor recebido na moeda da conta" do
      paid_order(9)

      expect(report.recent[:roas]).to be_nil
      expect(report.recent[:cac_cents]).to eq(5000)
    end

    it "tabela por anúncio na vida toda, do maior gasto para o menor, com vendas dos pedidos" do
      paid_order(9)

      expect(report.ads.map { |ad| ad.values_at(:name, :spend_cents, :sales, :meta_purchases, :cac_cents) })
        .to eq([ [ "method-01", 5000, 1, 1, 5000 ], [ "pain-01", 1000, 0, 0, nil ] ])
      expect(report.ads.map { |ad| ad[:name] }).not_to include("other-01")
    end

    it "oferece para vínculo só as campanhas sem produto" do
      pending_campaign = create(:ad_campaign, meta_campaign_id: "C-NOVA")

      expect(report.available_campaigns).to contain_exactly(pending_campaign)
    end
  end
end
