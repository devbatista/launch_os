require "rails_helper"

RSpec.describe WebhookEvent do
  it "é único por (provider, external_id)" do
    create(:webhook_event, external_id: "E1")

    expect(build(:webhook_event, external_id: "E1")).not_to be_valid
    expect(build(:webhook_event, external_id: "E1", provider: "twilio")).to be_valid
    expect { described_class.create!(provider: "paypal", external_id: "E1", event_type: "X") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "só aceita provedores conhecidos e exige tipo" do
    expect(build(:webhook_event, provider: "stripe")).not_to be_valid
    expect(build(:webhook_event, event_type: nil)).not_to be_valid
  end

  it "marca processed/ignored/failed" do
    event = create(:webhook_event)
    order = create(:order)

    event.mark_processed!(order:)
    expect(event).to have_attributes(status: "processed", order:)
    expect(event.processed_at).to be_present

    event.mark_failed!("boom")
    expect(event).to be_failed
    expect(event.error).to eq("boom")

    event.mark_ignored!("why")
    expect(event).to be_ignored
    expect(event.error).to eq("why")
  end
end
