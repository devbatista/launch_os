module Providers
  module Paypal
    # Captura o pedido no PayPal (spec 07, passo 3). ORDER_ALREADY_CAPTURED não é erro: buscamos o
    # pedido e devolvemos o mesmo formato (purchase_units[0].payments.captures[0] + payer).
    class CaptureOrder
      def self.call(order, client: Client.new) = new(client).call(order)

      def initialize(client) = @client = client

      def call(order)
        @client.capture_order(order.paypal_order_id, request_id: "capture-#{order.id}")
      rescue Client::ApiError => e
        raise unless e.issue?("ORDER_ALREADY_CAPTURED")

        @client.get_order(order.paypal_order_id)
      end
    end
  end
end
