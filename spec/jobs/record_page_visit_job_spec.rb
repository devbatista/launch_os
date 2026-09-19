require "rails_helper"

RSpec.describe RecordPageVisitJob do
  let(:product) { create(:product, :published) }

  it "grava a PageVisit com os campos de atribuição, sem IP cru" do
    expect do
      described_class.perform_now(product_id: product.id, path: "/reset", utm_source: "ig", utm_campaign: "launch", fbclid: "abc",
                                  referrer: "https://l.instagram.com/", user_agent: "Mozilla/5.0", ip_hash: "h" * 64, visitor_id: "v1")
    end.to change(PageVisit, :count).by(1)

    visit = PageVisit.last
    expect(visit).to have_attributes(product:, path: "/reset", utm_source: "ig", utm_campaign: "launch", fbclid: "abc", visitor_id: "v1", ip_hash: "h" * 64)
    expect(visit.attributes.keys).not_to include("ip_address", "ip")
  end

  it "ignora bots e descarta payload inválido sem levantar" do
    expect { described_class.perform_now(product_id: product.id, path: "/reset", user_agent: "Googlebot/2.1") }.not_to change(PageVisit, :count)
    expect { described_class.perform_now(product_id: product.id, path: "", user_agent: "Mozilla/5.0") }.not_to raise_error
    expect(PageVisit.count).to eq(0)
  end
end
