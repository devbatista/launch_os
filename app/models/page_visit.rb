# Visita à LP (spec 10, analytics interno): origem da campanha, visitante (cookie lo_vid) e hash do IP —
# nunca o IP. Gravada por RecordPageVisitJob a partir do beacon POST /visits (o Thruster cacheia a LP,
# então o controller da página não vê a maioria dos acessos). Bots conhecidos são descartados.
class PageVisit < ApplicationRecord
  BOT_USER_AGENT = /bot|crawler|spider|facebookexternalhit|headless|lighthouse/i
  ATTRIBUTION_FIELDS = %w[utm_source utm_medium utm_campaign utm_content utm_term fbclid referrer].freeze

  belongs_to :product, optional: true

  validates :path, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :humans, -> { where.not(user_agent: nil).where.not("user_agent ~* ?", BOT_USER_AGENT.source) }

  def self.bot?(user_agent) = user_agent.blank? || user_agent.match?(BOT_USER_AGENT)

  # SHA-256 do IP com sal diário (secret_key_base + data): permite "mesmo IP no dia" sem guardar o IP.
  def self.ip_hash(ip, date: Date.current)
    return nil if ip.blank?

    Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:#{date.iso8601}:#{ip}")
  end
end
