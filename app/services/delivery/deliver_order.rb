module Delivery
  # Primeira entrega após Orders::MarkPaid: enfileira o email `order_delivery` (e o WhatsApp, quando a
  # 2.7 existir). Só para pedido pago com token ativo — o job pode rodar depois de um refund rápido.
  class DeliverOrder
    def self.call(order) = new.call(order)

    def call(order)
      return false unless order.paid? && order.download_token&.active?

      SendOrderEmailJob.perform_later(order.id, template: "order_delivery")
      # 2.7: SendWhatsappMessageJob.perform_later(order.id, template: "order_delivery") if whatsapp?(order)
      true
    end
  end
end
