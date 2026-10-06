require "rails_helper"

RSpec.describe MetaAds::CampaignSnapshot do
  let(:product) { create(:product, :published) }
  let(:zone) { Time.find_zone("America/Sao_Paulo") }
  let(:client) { instance_double(Providers::Meta::Client) }

  around { |example| travel_to(Time.find_zone("America/Sao_Paulo").local(2026, 10, 6, 15)) { example.run } }

  def at(day, hour = 10) = zone.local(2026, 10, day, hour)
  def snapshot(**opts) = described_class.call(product, live: false, **opts)

  before do
    create(:ad_campaign, meta_campaign_id: "C1", name: "Reset | Vendas", product:)
    create(:ad_insight, meta_campaign_id: "C1", meta_ad_id: "A1", ad_name: "method-01", date: Date.new(2026, 10, 2),
                        spend_cents: 1000, impressions: 400, link_clicks: 8, landing_page_views: 6, initiate_checkouts: 1)
    create(:ad_insight, meta_campaign_id: "C1", meta_ad_id: "A1", ad_name: "method-01", date: Date.new(2026, 10, 5),
                        spend_cents: 3000, impressions: 600, link_clicks: 12, landing_page_views: 8, purchases: 1)
    create(:ad_insight, meta_campaign_id: "C1", meta_ad_id: "A2", ad_name: "pain-01", date: Date.new(2026, 10, 5),
                        spend_cents: 1000, impressions: 1000, link_clicks: 5, landing_page_views: 2)
  end

  it "totais do período com taxas calculadas, cruzando Insights, visitas e pedidos da Meta" do
    create_list(:page_visit, 2, :from_campaign, product:, utm_content: "method-01", created_at: at(5))
    create(:page_visit, :from_campaign, product:, utm_content: "method-01", visitor_id: "v-repetido", created_at: at(5))
    create(:page_visit, :from_campaign, product:, utm_content: "method-01", visitor_id: "v-repetido", created_at: at(5, 11))
    create(:page_visit, :from_campaign, product:, user_agent: "facebookexternalhit/1.1", created_at: at(5)) # bot: fora
    create(:order, :paid, product:, utm_source: "facebook", utm_content: "method-01", created_at: at(5),
                          paypal_receivable_cents: 6860, paypal_receivable_currency: "BRL", paypal_exchange_rate: 4.89, payer_country: "US")
    create(:order, :pending, product:, utm_source: "facebook", utm_content: "pain-01", created_at: at(5))
    create(:order, :paid, product:, utm_source: nil, created_at: at(5)) # orgânico: fora da Meta

    result = snapshot

    expect(result[:period]).to eq(since: "2026-10-02", until: "2026-10-06", days: 5)
    expect(result[:ad_spend_currency]).to eq("BRL")
    expect(result[:paypal_usd_brl_rate]).to eq(4.89)
    expect(result[:totals]).to include(
      spend_cents: 5000, impressions: 2000, link_clicks: 25, landing_page_views: 16, initiate_checkouts: 1, purchases: 1,
      visits: 4, unique_visitors: 3, checkouts: 2, sales: 1,
      ctr: 1.25, cpc_cents: 200, cpm_cents: 2500, lp_view_rate: 64.0, initiate_checkout_rate: 6.25,
      checkout_per_visitor: 66.67, sale_per_checkout: 50.0, cac_cents: 5000
    )
    expect(result[:orders]).to eq(
      meta_by_status: { "paid" => 1, "pending" => 1 }, meta_paid_by_country: { "US" => 1 },
      other_sources_by_status: { "paid" => 1 }, meta_paid_received: { "BRL" => 6860 }, roas: 1.37
    )
  end

  it "um registro por dia do período, inclusive dias sem veiculação" do
    daily = snapshot[:daily]

    expect(daily.map { |d| d[:date] }).to eq(%w[2026-10-02 2026-10-03 2026-10-04 2026-10-05 2026-10-06])
    expect(daily.map { |d| d[:spend_cents] }).to eq([ 1000, 0, 0, 4000, 0 ])
    expect(daily.second).to include(impressions: 0, ctr: nil, cpc_cents: nil, cac_cents: nil)
  end

  it "por anúncio do maior gasto para o menor, e utm_content sem anúncio correspondente em unmatched" do
    create(:order, :paid, product:, utm_source: "facebook", utm_content: "method-01", created_at: at(5))
    create(:page_visit, :from_campaign, product:, utm_content: "typo-01", created_at: at(5))

    ads = snapshot[:ads]

    expect(ads[:list].map { |ad| ad.values_at(:name, :meta_ad_ids, :spend_cents, :sales, :cac_cents) })
      .to eq([ [ "method-01", [ "A1" ], 4000, 1, 4000 ], [ "pain-01", [ "A2" ], 1000, 0, nil ] ])
    expect(ads[:unmatched]).to eq(visits: { "typo-01" => 1 }, checkouts: {})
  end

  it "respeita o período pedido e aponta campanha sem produto com gasto" do
    create(:ad_campaign, meta_campaign_id: "C-SOLTA", name: "Leads Set/2026")
    create(:ad_insight, meta_campaign_id: "C-SOLTA", campaign_name: "Leads Set/2026", date: Date.new(2026, 10, 5), spend_cents: 777)

    result = snapshot(since: Date.new(2026, 10, 5), until_date: Date.new(2026, 10, 5))

    expect(result[:totals][:spend_cents]).to eq(4000)
    expect(result[:unassigned_campaigns]).to eq([ { meta_campaign_id: "C-SOLTA", name: "Leads Set/2026", spend_cents: 777 } ])
    expect { snapshot(since: Date.new(2026, 10, 6), until_date: Date.new(2026, 10, 5)) }.to raise_error(ArgumentError)
  end

  it "nunca expõe dados pessoais do comprador" do
    create(:order, :paid, :with_attribution, product:, utm_source: "facebook", created_at: at(5), phone: "+15555550123")

    json = snapshot.to_json
    order = Order.last

    [ order.payer_email, order.payer_name, order.phone, order.ip_address, order.id, order.paypal_order_id ].each do |value|
      expect(json).not_to include(value)
    end
  end

  context "com o estado ao vivo na Meta" do
    def live_snapshot = described_class.call(product, client:, live: true)

    it "filtra pelas campanhas do produto e traz orçamento, aprendizado, alcance e rankings" do
      allow(client).to receive(:reach_insights).with(level: "campaign", since: Date.new(2026, 10, 2), until_date: Date.new(2026, 10, 6))
        .and_return([ { "campaign_id" => "C1", "reach" => "1500", "frequency" => "1.333" } ])
      allow(client).to receive(:reach_insights).with(level: "ad", since: Date.new(2026, 10, 2), until_date: Date.new(2026, 10, 6))
        .and_return([ { "ad_id" => "A1", "reach" => "800", "frequency" => "1.25", "quality_ranking" => "AVERAGE" } ])
      allow(client).to receive_messages(
        campaigns: [
          { "id" => "C1", "name" => "Reset | Vendas", "effective_status" => "ACTIVE", "objective" => "OUTCOME_SALES", "daily_budget" => "2800" },
          { "id" => "C-OUTRA", "name" => "Outra", "effective_status" => "PAUSED" }
        ],
        ad_sets: [
          { "id" => "S1", "campaign_id" => "C1", "effective_status" => "ACTIVE", "learning_stage_info" => { "status" => "LEARNING", "conversions" => 1 },
            "issues_info" => [ { "level" => "AD_SET", "error_code" => 1, "error_summary" => "Baixa entrega", "error_message" => "..." } ] }
        ],
        ads: [
          { "id" => "A1", "name" => "method-01", "adset_id" => "S1", "campaign_id" => "C1", "effective_status" => "ACTIVE" },
          { "id" => "A3", "name" => "outcome-01", "adset_id" => "S1", "campaign_id" => "C1", "effective_status" => "DISAPPROVED" }
        ]
      )

      live = live_snapshot[:live]

      expect(live[:campaigns]).to eq([ { id: "C1", name: "Reset | Vendas", effective_status: "ACTIVE", objective: "OUTCOME_SALES",
                                         bid_strategy: nil, daily_budget_cents: 2800, lifetime_budget_cents: nil, start_time: nil,
                                         stop_time: nil, issues: [], reach: 1500, frequency: 1.33 } ])
      expect(live[:ad_sets].first).to include(learning_status: "LEARNING", learning_conversions: 1,
                                               issues: [ { "level" => "AD_SET", "error_code" => 1, "error_summary" => "Baixa entrega", "error_message" => "..." } ])
      expect(live[:ads].map { |a| a.values_at(:name, :effective_status, :reach, :quality_ranking) })
        .to eq([ [ "method-01", "ACTIVE", 800, "AVERAGE" ], [ "outcome-01", "DISAPPROVED", nil, nil ] ])
    end

    it "falha da Meta não derruba o retrato: a parte do banco sai e live.error explica" do
      allow(client).to receive(:reach_insights).and_raise(Providers::Meta::Client::ApiError.new("Meta 190: token expirado", code: 190, status: 400))

      result = live_snapshot

      expect(result[:live]).to eq(enabled: true, error: "Meta 190: token expirado")
      expect(result[:totals][:spend_cents]).to eq(5000)
    end

    it "sem credenciais, ou sem campanha vinculada, não chama a Meta" do
      expect(snapshot[:live]).to eq(enabled: false)

      product.ad_campaigns.update_all(product_id: nil)
      expect(live_snapshot[:live]).to eq(enabled: true, error: "nenhuma campanha vinculada ao produto")
    end
  end
end
