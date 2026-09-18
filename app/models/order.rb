# Pedido (docs/specs/03-modelo-de-dados.md, 07-checkout-paypal.md). Criado em `pending` no
# POST /checkout/paypal com o preço copiado do produto; muda de status SÓ pelos services Orders::*.
class Order < ApplicationRecord
  ATTRIBUTION_FIELDS = %w[utm_source utm_medium utm_campaign utm_content utm_term fbclid referrer landing_path].freeze
  PHONE_FORMAT = /\A\+[1-9]\d{6,14}\z/ # E.164

  belongs_to :client, optional: true
  belongs_to :product

  enum :status, { pending: "pending", paid: "paid", failed: "failed", refunded: "refunded", disputed: "disputed" }, default: :pending

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, length: { is: 3 }
  validates :phone, format: { with: PHONE_FORMAT }, allow_nil: true
  validates :paypal_order_id, :paypal_capture_id, uniqueness: true, allow_nil: true
  validate :whatsapp_opt_in_requires_phone

  before_create { self.event_id ||= SecureRandom.uuid }

  scope :recent, -> { order(created_at: :desc) }

  def amount = amount_cents.to_d / 100

  private
    def whatsapp_opt_in_requires_phone
      errors.add(:whatsapp_opt_in, "requires a phone number") if whatsapp_opt_in? && phone.blank?
    end
end
