require "rails_helper"

RSpec.describe AdInsight do
  subject { build(:ad_insight) }

  it { is_expected.to validate_presence_of(:ad_name) }
  it { is_expected.to validate_presence_of(:currency) }
  it { is_expected.to validate_uniqueness_of(:meta_ad_id).scoped_to(:date).ignoring_case_sensitivity }
  it { is_expected.to validate_numericality_of(:spend_cents).only_integer.is_greater_than_or_equal_to(0) }

  it "filtra por intervalo de datas" do
    inside = create(:ad_insight, date: Date.new(2026, 10, 3))
    create(:ad_insight, date: Date.new(2026, 9, 20))

    expect(described_class.between(Date.new(2026, 10, 1)..Date.new(2026, 10, 5))).to contain_exactly(inside)
  end
end
