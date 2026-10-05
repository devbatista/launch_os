require "rails_helper"

RSpec.describe MetaAds::SyncInsights, :meta do
  let(:actions) do
    { "landing_page_view" => "8", "offsite_conversion.fb_pixel_initiate_checkout" => "2", "offsite_conversion.fb_pixel_purchase" => "1",
      "omni_purchase" => "3", "link_click" => "10" }
  end

  it "grava uma linha por anúncio e dia, com gasto em centavos e só as ações do Pixel" do
    stub_meta_insights([ meta_insight_row(spend: "62.1", impressions: "748", clicks: "10", actions:),
                         meta_insight_row(ad_id: "120000000000000002", ad_name: "pain-01", spend: "9.33") ])

    expect(described_class.call(since: Date.new(2026, 10, 2), until_date: Date.new(2026, 10, 4))).to eq(2)

    insight = AdInsight.find_by!(ad_name: "method-01")
    expect(insight).to have_attributes(date: Date.new(2026, 10, 3), meta_ad_id: "120000000000000001", spend_cents: 6210, currency: "BRL",
                                       impressions: 748, link_clicks: 10, landing_page_views: 8, initiate_checkouts: 2, purchases: 1,
                                       campaign_name: "Reset | Vendas | DevBatista | Outubro/2026")
    expect(AdInsight.find_by!(ad_name: "pain-01")).to have_attributes(spend_cents: 933, landing_page_views: 0, purchases: 0)
  end

  it "é idempotente: rodar de novo atualiza a mesma linha (a Meta revisa a atribuição)" do
    stub_meta_insights([ meta_insight_row(spend: "20.00") ])
    described_class.call

    stub_meta_insights([ meta_insight_row(spend: "25.40", actions: { "offsite_conversion.fb_pixel_purchase" => "1" }) ])
    expect { described_class.call }.not_to change(AdInsight, :count)

    expect(AdInsight.sole).to have_attributes(spend_cents: 2540, purchases: 1)
  end

  it "sem datas, reprocessa os últimos 7 dias até hoje no fuso da conta" do
    travel_to Time.zone.parse("2026-10-05 02:00 UTC") do # 23:00 de 04/10 em São Paulo
      stub = stub_request(:get, MetaStubs::INSIGHTS_URL)
        .with(query: hash_including("time_range" => { since: "2026-09-27", until: "2026-10-04" }.to_json))
        .to_return(status: 200, body: { data: [] }.to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.call).to eq(0)
      expect(stub).to have_been_requested
    end
  end

  it "recusa janela invertida" do
    expect { described_class.call(since: Date.new(2026, 10, 5), until_date: Date.new(2026, 10, 1)) }.to raise_error(ArgumentError)
  end
end
