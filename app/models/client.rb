# Comprador (docs/specs/03-modelo-de-dados.md). Criado/atualizado por Orders::MarkPaid a partir do
# pagador devolvido pelo PayPal; o opt-in de WhatsApp guarda o texto exato aceito e a data (TCPA).
class Client < ApplicationRecord
  has_many :orders, dependent: :nullify

  normalizes :email, with: ->(e) { e.to_s.strip.downcase }
  normalizes :phone, with: ->(p) { p.presence }

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: URI::MailTo::EMAIL_REGEXP
  validates :phone, phone: { allow_blank: true }
  validates :country, length: { is: 2 }, allow_blank: true

  def whatsapp_deliverable? = whatsapp_opt_in? && phone.present? && whatsapp_opt_out_at.nil?

  def opt_out_whatsapp!
    update!(whatsapp_opt_in: false, whatsapp_opt_out_at: Time.current)
  end
end
