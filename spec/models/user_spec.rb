require "rails_helper"

RSpec.describe User do
  describe "validações" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_uniqueness_of(:email_address).case_insensitive }
    it { is_expected.to have_many(:sessions).dependent(:destroy) }

    it "rejeita senha com 11 caracteres" do
      user = build(:user, password: "a" * 11)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "aceita senha com 12 caracteres" do
      expect(build(:user, password: "a" * 12)).to be_valid
    end

    it "normaliza o email (strip + downcase)" do
      user = create(:user, email_address: "  Admin@Example.COM ")

      expect(user.email_address).to eq("admin@example.com")
    end
  end

  describe "#locked?" do
    it "é falso sem locked_at" do
      expect(build(:user)).not_to be_locked
    end

    it "é verdadeiro dentro dos 15 minutos" do
      expect(build(:user, locked_at: 14.minutes.ago)).to be_locked
    end

    it "é falso depois dos 15 minutos" do
      expect(build(:user, locked_at: 16.minutes.ago)).not_to be_locked
    end
  end

  describe "#register_failed_attempt!" do
    it "incrementa o contador sem bloquear antes da 5ª falha" do
      user = create(:user)

      4.times { user.register_failed_attempt! }

      expect(user.reload.failed_attempts).to eq(4)
      expect(user).not_to be_locked
    end

    it "bloqueia na 5ª falha" do
      user = create(:user)

      5.times { user.register_failed_attempt! }

      expect(user.reload).to be_locked
      expect(user.locked_at).to be_within(1.second).of(Time.current)
    end

    it "zera a contagem quando um bloqueio antigo já expirou" do
      user = create(:user, failed_attempts: 5, locked_at: 20.minutes.ago)

      user.register_failed_attempt!

      expect(user.reload.failed_attempts).to eq(1)
      expect(user).not_to be_locked
    end
  end

  describe "#register_successful_sign_in!" do
    it "limpa falhas e bloqueio e registra o horário" do
      user = create(:user, failed_attempts: 3, locked_at: 20.minutes.ago)

      user.register_successful_sign_in!

      expect(user.reload).to have_attributes(failed_attempts: 0, locked_at: nil)
      expect(user.last_sign_in_at).to be_within(1.second).of(Time.current)
    end
  end
end
