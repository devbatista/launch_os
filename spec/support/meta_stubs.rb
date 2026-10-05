# Stubs WebMock da Graph API da Meta (Insights) — nenhuma chamada real nos specs. Tag `:meta` liga a
# integração com credenciais de teste.
module MetaStubs
  ACCESS_TOKEN = "test-meta-token".freeze
  AD_ACCOUNT_ID = "1234567890".freeze
  INSIGHTS_URL = "#{Providers::Meta::Client::BASE}/#{Providers::Meta::Client::DEFAULT_VERSION}/act_#{AD_ACCOUNT_ID}/insights".freeze

  # Linha do Insights no formato da API (números como string, ações em lista de action_type/value).
  def meta_insight_row(ad_id: "120000000000000001", ad_name: "method-01", date: "2026-10-03", spend: "25.40",
                       impressions: "300", clicks: "4", actions: {})
    { "ad_id" => ad_id, "ad_name" => ad_name, "campaign_id" => "120000000000000000",
      "campaign_name" => "Reset | Vendas | DevBatista | Outubro/2026", "date_start" => date, "date_stop" => date,
      "spend" => spend, "account_currency" => "BRL", "impressions" => impressions, "inline_link_clicks" => clicks,
      "actions" => actions.map { |type, value| { "action_type" => type, "value" => value } } }
  end

  def stub_meta_insights(rows, next_url: nil)
    body = { data: rows, paging: next_url ? { next: next_url } : {} }
    stub_request(:get, INSIGHTS_URL).with(query: hash_including("access_token" => ACCESS_TOKEN))
      .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_meta_error(code:, message:, http_status: 400, is_transient: false)
    stub_request(:get, INSIGHTS_URL).with(query: hash_including({}))
      .to_return(status: http_status, body: { error: { message:, type: "OAuthException", code:, is_transient:, fbtrace_id: "Atest" } }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end
end

RSpec.configure do |config|
  config.include MetaStubs

  config.before(:each, :meta) do
    stub_const("ENV", ENV.to_h.merge("META_ACCESS_TOKEN" => MetaStubs::ACCESS_TOKEN, "META_AD_ACCOUNT_ID" => "act_#{MetaStubs::AD_ACCOUNT_ID}"))
  end
end
