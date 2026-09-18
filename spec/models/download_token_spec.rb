require "rails_helper"

RSpec.describe DownloadToken do
  it "gera token urlsafe único, prazo de DOWNLOAD_TOKEN_TTL_DAYS e limite padrão" do
    token = create(:download_token)

    expect(token.token).to match(/\A[A-Za-z0-9_-]{36,}\z/)
    expect(token.expires_at).to be_within(1.minute).of(7.days.from_now)
    expect(token.max_downloads).to eq(10)
    expect(token).to be_active
    expect(create(:download_token).token).not_to eq(token.token)
  end

  it "é 1:1 com o pedido" do
    token = create(:download_token)

    expect { create(:download_token, order: token.order) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "#inactive_reason" do
    it "not_paid para pedido pending/failed; revogado tem precedência (refund/disputa → 410)" do
      expect(build(:download_token, :unpaid).inactive_reason).to eq(:not_paid)
      expect(build(:download_token, order: build(:order, :failed)).inactive_reason).to eq(:not_paid)
      expect(build(:download_token, :revoked, order: build(:order, :refunded)).inactive_reason).to eq(:revoked)
    end

    it "revoked, expired, limit_reached, nil quando ativo" do
      expect(build(:download_token, :revoked).inactive_reason).to eq(:revoked)
      expect(build(:download_token, :expired).inactive_reason).to eq(:expired)
      expect(build(:download_token, :limit_reached).inactive_reason).to eq(:limit_reached)
      expect(build(:download_token).inactive_reason).to be_nil
    end
  end

  it "revoke! é idempotente e regenerate! renova tudo (só para pedido pago)" do
    token = create(:download_token, :limit_reached, :expired)
    old = token.token

    token.revoke!
    revoked_at = token.revoked_at
    token.revoke!
    expect(token.revoked_at).to eq(revoked_at)

    token.regenerate!
    expect(token.token).not_to eq(old)
    expect(token).to have_attributes(download_count: 0, revoked_at: nil)
    expect(token.expires_at).to be > 6.days.from_now
    expect(token).to be_active

    unpaid = create(:download_token, :unpaid)
    expect { unpaid.regenerate! }.to raise_error(ArgumentError)
  end

  it "register_download! incrementa sob lock e bloqueia no limite" do
    token = create(:download_token, max_downloads: 2)

    token.register_download!
    token.register_download!
    expect(token.reload).to have_attributes(download_count: 2, remaining_downloads: 0)
    expect(token.last_downloaded_at).to be_present
    expect(token).not_to be_active
    expect { token.register_download! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(token.reload.download_count).to eq(2)
  end
end
