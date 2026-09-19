require "rails_helper"

# POST /visits (spec 10): beacon da LP → RecordPageVisitJob; a LP é cacheada, então este endpoint conta as visitas.
RSpec.describe "Visits beacon" do
  let!(:product) { create(:product, :published, slug: "reset") }

  def beacon(payload, headers: {})
    post visits_path, params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone)" }.merge(headers)
  end

  it "enfileira o job com produto, UTMs, referrer, visitante do cookie e hash do IP — nunca o IP" do
    cookies[:lo_vid] = "vid-123"

    expect do
      beacon({ product: "reset", path: "/reset", utm_source: "ig", utm_campaign: "launch", fbclid: "abc", referrer: "https://l.instagram.com/", visitor_id: "ignored-when-cookie" })
    end.to have_enqueued_job(RecordPageVisitJob).with(hash_including(
      product_id: product.id, path: "/reset", utm_source: "ig", utm_campaign: "launch", fbclid: "abc",
      referrer: "https://l.instagram.com/", visitor_id: "vid-123", user_agent: "Mozilla/5.0 (iPhone)", ip_hash: PageVisit.ip_hash("127.0.0.1")
    ))
    expect(response).to have_http_status(:no_content)
  end

  it "produto desconhecido vira visita sem produto; sem cookie usa o visitor_id do payload; valores longos são truncados" do
    expect { beacon({ product: "nope", path: "/x", visitor_id: "v-2", utm_term: "t" * 400 }) }
      .to have_enqueued_job(RecordPageVisitJob).with(hash_including(product_id: nil, path: "/x", visitor_id: "v-2", utm_term: "t" * 255))
  end

  it "bots não geram job (T-bot); rate limit por IP → 429" do
    expect { beacon({ product: "reset" }, headers: { "HTTP_USER_AGENT" => "facebookexternalhit/1.1" }) }.not_to have_enqueued_job(RecordPageVisitJob)
    expect(response).to have_http_status(:no_content)

    60.times { beacon({ product: "reset" }) }
    beacon({ product: "reset" })
    expect(response).to have_http_status(:too_many_requests)
  end
end
