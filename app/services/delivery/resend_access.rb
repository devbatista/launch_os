module Delivery
  # Reenvio do link (/access/recover ou admin): regenera o token se expirou ou bateu o limite — nunca se
  # foi revogado (refund, disputa ou admin) — e enfileira o email `access_resend`. Devolve false quando
  # não há o que reenviar (pedido não pago ou token revogado).
  class ResendAccess
    def self.call(order, channels: [ :email ]) = new.call(order, channels:)

    def call(order, channels: [ :email ])
      return false unless order.paid?

      token = order.download_token || order.create_download_token!
      return false if token.revoked_at.present?

      token.regenerate! unless token.active?
      SendOrderEmailJob.perform_later(order.id, template: "access_resend") if channels.include?(:email)
      # 2.7: SendWhatsappMessageJob.perform_later(order.id, template: "access_resend") if channels.include?(:whatsapp) && ...
      true
    end
  end
end
