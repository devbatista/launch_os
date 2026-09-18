# Registro de cada mensagem enviada ao comprador (spec 09): canal, template, destinatário e o ciclo
# queued → sent → delivered/read (WhatsApp, via status callback) ou failed/undelivered. O admin (2.8)
# mostra isso no pedido; o Sidekiq atualiza `attempts` e `error_*` a cada tentativa.
class MessageLog < ApplicationRecord
  belongs_to :order
  belongs_to :client, optional: true

  enum :channel, { email: "email", whatsapp: "whatsapp" }, prefix: true
  enum :template, { order_delivery: "order_delivery", access_resend: "access_resend",
                    refund_confirmation: "refund_confirmation", inbound: "inbound" }, prefix: true
  enum :status, { queued: "queued", sent: "sent", delivered: "delivered", read: "read",
                  failed: "failed", undelivered: "undelivered" }, default: :queued

  validates :recipient, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def mark_sent!(provider_message_id)
    update!(status: :sent, sent_at: Time.current, provider_message_id:, error_code: nil, error_message: nil)
  end

  # Erro transitório: registra e mantém `queued` (o job vai tentar de novo).
  def register_attempt!(error)
    update!(attempts: attempts + 1, error_message: error.message.truncate(1000))
  end

  def mark_failed!(error, code: nil)
    update!(status: :failed, failed_at: Time.current, attempts: attempts + 1, error_code: code,
            error_message: error.message.truncate(1000))
  end
end
