require "rails_helper"

RSpec.describe AdCampaign do
  subject { build(:ad_campaign) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:meta_campaign_id) }
  it { is_expected.to validate_uniqueness_of(:meta_campaign_id).ignoring_case_sensitivity }
  it { is_expected.to belong_to(:product).optional }

  it "liga os insights pelo id da campanha na Meta e separa vinculadas de pendentes" do
    product = create(:product, :published)
    linked = create(:ad_campaign, meta_campaign_id: "C1", product:)
    pending = create(:ad_campaign, meta_campaign_id: "C2")
    insight = create(:ad_insight, meta_campaign_id: "C1")

    expect(linked.ad_insights).to contain_exactly(insight)
    expect(insight.ad_campaign).to eq(linked)
    expect(described_class.assigned).to contain_exactly(linked)
    expect(described_class.unassigned).to contain_exactly(pending)
  end

  it "remover o produto desfaz o vínculo sem apagar a campanha" do
    product = create(:product, :published)
    campaign = create(:ad_campaign, product:)

    product.destroy!

    expect(campaign.reload.product_id).to be_nil
  end
end
