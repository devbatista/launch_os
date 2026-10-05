require "rails_helper"

RSpec.describe SyncAdInsightsJob do
  it "não faz nada sem META_ACCESS_TOKEN/META_AD_ACCOUNT_ID" do
    stub_const("ENV", ENV.to_h.except("META_ACCESS_TOKEN", "META_AD_ACCOUNT_ID"))

    expect { described_class.perform_now }.not_to raise_error
    expect(a_request(:any, /graph\.facebook\.com/)).not_to have_been_made
  end

  context "com a integração configurada", :meta do
    it "sincroniza a janela pedida (backfill com datas ISO8601)" do
      stub = stub_request(:get, MetaStubs::INSIGHTS_URL)
        .with(query: hash_including("time_range" => { since: "2026-10-02", until: "2026-10-04" }.to_json))
        .to_return(status: 200, body: { data: [ meta_insight_row ] }.to_json, headers: { "Content-Type" => "application/json" })

      expect { described_class.perform_now("2026-10-02", "2026-10-04") }.to change(AdInsight, :count).by(1)
      expect(stub).to have_been_requested
    end

    it "erro permanente (token expirado) → descarta e reporta, sem retry" do
      stub_meta_error(code: 190, message: "Session has expired")
      allow(Sentry).to receive(:capture_exception)

      expect { described_class.perform_now }.not_to raise_error
      expect(Sentry).to have_received(:capture_exception).with(an_instance_of(Providers::Meta::Client::ApiError))
      expect(enqueued_jobs).to be_empty
    end

    it "erro transitório (rate limit) → reagenda o job" do
      stub_meta_error(code: 17, message: "User request limit reached")

      described_class.perform_now

      expect(described_class).to have_been_enqueued
    end
  end

  it "está agendado no config/schedule.yml com cron válido" do
    entry = YAML.load_file(Rails.root.join("config/schedule.yml")).fetch("sync_ad_insights")
    job = Sidekiq::Cron::Job.new(entry.merge("name" => "sync_ad_insights"))

    expect(job).to be_valid
    expect(entry["class"].constantize).to eq(described_class)
  end
end
