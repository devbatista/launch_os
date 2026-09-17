# Único usuário do MVP: o admin (docs/specs/04-autenticacao-admin.md).
# Sem cadastro público; criado via seed (ADMIN_EMAIL/ADMIN_PASSWORD) ou console.
class User < ApplicationRecord
  PASSWORD_MIN_LENGTH = 12
  MAX_FAILED_ATTEMPTS = 5
  LOCK_DURATION = 15.minutes

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: PASSWORD_MIN_LENGTH }, allow_nil: true

  def locked?
    locked_at.present? && locked_at > LOCK_DURATION.ago
  end

  # Incrementa o contador de falhas e bloqueia ao atingir o limite. Um bloqueio já expirado
  # zera a contagem antes de incrementar, para que 5 falhas antigas não bloqueiem na 1ª falha nova.
  def register_failed_attempt!
    with_lock do
      self.failed_attempts = 0 if locked_at.present? && !locked?
      self.failed_attempts += 1
      self.locked_at = Time.current if failed_attempts >= MAX_FAILED_ATTEMPTS && !locked?
      save!(validate: false)
    end
  end

  def register_successful_sign_in!
    update_columns(failed_attempts: 0, locked_at: nil, last_sign_in_at: Time.current, updated_at: Time.current)
  end
end
