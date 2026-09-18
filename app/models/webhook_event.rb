# Evento recebido de um provedor (docs/specs/03, 07). A unicidade (provider, external_id) é a chave de
# idempotência: o mesmo evento reenviado pelo PayPal vira uma única linha e não é processado duas vezes.
class WebhookEvent < ApplicationRecord
  PROVIDERS = %w[paypal twilio].freeze

  belongs_to :order, optional: true

  enum :status, { received: "received", processed: "processed", ignored: "ignored", failed: "failed" }, default: :received

  validates :provider, inclusion: { in: PROVIDERS }
  validates :external_id, :event_type, presence: true
  validates :external_id, uniqueness: { scope: :provider }

  scope :recent, -> { order(created_at: :desc) }

  def mark_processed!(order: nil)
    update!(status: :processed, processed_at: Time.current, order: order || self.order, error: nil)
  end

  def mark_ignored!(reason = nil, order: nil)
    update!(status: :ignored, processed_at: Time.current, order: order || self.order, error: reason)
  end

  def mark_failed!(error)
    update!(status: :failed, error: error.to_s.truncate(2000))
  end
end
