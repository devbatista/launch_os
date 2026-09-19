require "rails_helper"

RSpec.describe PageVisit do
  it { is_expected.to belong_to(:product).optional }
  it { is_expected.to validate_presence_of(:path) }

  it "reconhece bots conhecidos e user agent vazio" do
    expect(described_class.bot?("facebookexternalhit/1.1")).to be(true)
    expect(described_class.bot?("Mozilla/5.0 (compatible; Googlebot/2.1)")).to be(true)
    expect(described_class.bot?("")).to be(true)
    expect(described_class.bot?("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)")).to be(false)
  end

  it "ip_hash é estável no dia, muda com o dia e com o IP, e nunca é o IP" do
    a = described_class.ip_hash("203.0.113.10")
    expect(a).to match(/\A\h{64}\z/)
    expect(described_class.ip_hash("203.0.113.10")).to eq(a)
    expect(described_class.ip_hash("203.0.113.10", date: Date.current + 1)).not_to eq(a)
    expect(described_class.ip_hash("203.0.113.11")).not_to eq(a)
    expect(described_class.ip_hash(nil)).to be_nil
  end

  it "humans exclui bots e sem user agent" do
    create(:page_visit, user_agent: "Mozilla/5.0")
    create(:page_visit, user_agent: "Googlebot")
    create(:page_visit, user_agent: nil)
    expect(described_class.humans.count).to eq(1)
  end
end
