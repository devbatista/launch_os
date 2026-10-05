require "rails_helper"

RSpec.describe Providers::Meta::Client, :meta do
  let(:client) { described_class.new }
  let(:since) { Date.new(2026, 10, 2) }
  let(:until_date) { Date.new(2026, 10, 5) }

  def fetch = client.ad_insights(since:, until_date:)

  it "pede o Insights por anúncio e dia, na versão fixada, com a atribuição da conta (act_ removido do id)" do
    stub = stub_request(:get, MetaStubs::INSIGHTS_URL).with(query: {
      "level" => "ad", "time_increment" => "1", "limit" => "500", "use_account_attribution_setting" => "true",
      "fields" => "ad_id,ad_name,campaign_id,campaign_name,date_start,spend,account_currency,impressions,inline_link_clicks,actions",
      "time_range" => { since: "2026-10-02", until: "2026-10-05" }.to_json, "access_token" => MetaStubs::ACCESS_TOKEN
    }).to_return(status: 200, body: { data: [ meta_insight_row ] }.to_json, headers: { "Content-Type" => "application/json" })

    expect(fetch).to eq([ meta_insight_row ])
    expect(stub).to have_been_requested
  end

  it "segue paging.next até a última página" do
    next_url = "#{MetaStubs::INSIGHTS_URL}?after=CURSOR2&access_token=#{MetaStubs::ACCESS_TOKEN}"
    stub_request(:get, MetaStubs::INSIGHTS_URL).with(query: hash_including("level" => "ad"))
      .to_return(status: 200, body: { data: [ meta_insight_row(ad_name: "pain-01") ], paging: { next: next_url } }.to_json,
                 headers: { "Content-Type" => "application/json" })
    stub_request(:get, next_url)
      .to_return(status: 200, body: { data: [ meta_insight_row(ad_name: "outcome-01") ], paging: {} }.to_json,
                 headers: { "Content-Type" => "application/json" })

    expect(fetch.map { |row| row["ad_name"] }).to eq(%w[pain-01 outcome-01])
  end

  it "token inválido (190) e parâmetro (100) → ApiError permanente com o código, sem vazar o token" do
    stub_meta_error(code: 190, message: "Error validating access token: Session has expired")
    expect { fetch }.to raise_error(described_class::ApiError) { |e|
      expect(e.code).to eq(190)
      expect(e.message).to include("190").and(not_include(MetaStubs::ACCESS_TOKEN))
    }

    stub_meta_error(code: 100, message: "Invalid parameter")
    expect { fetch }.to raise_error(Providers::PermanentError, /100/)
  end

  it "rate limit (4, 17, 613, 80000), is_transient, 5xx e timeout → TransientError" do
    [ 4, 17, 613, 80_000 ].each do |code|
      stub_meta_error(code:, message: "User request limit reached")
      expect { fetch }.to raise_error(Providers::TransientError, /#{code}/)
    end

    stub_meta_error(code: 2, message: "Service temporarily unavailable", is_transient: true)
    expect { fetch }.to raise_error(Providers::TransientError)

    stub_request(:get, MetaStubs::INSIGHTS_URL).with(query: hash_including({})).to_return(status: 503, body: "unavailable")
    expect { fetch }.to raise_error(Providers::TransientError)

    stub_request(:get, MetaStubs::INSIGHTS_URL).with(query: hash_including({})).to_timeout
    expect { fetch }.to raise_error(Providers::TransientError, /expired|Timeout/)
  end

  matcher :not_include do |expected|
    match { |actual| !actual.include?(expected) }
  end
end
