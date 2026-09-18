module Providers
  module Paypal
    # Monta o pedido do PayPal a partir do Order (spec 07, passo 4) e grava o paypal_order_id.
    # O valor vem SEMPRE de order.amount_cents (copiado do produto) — nunca do navegador.
    class CreateOrder
      def self.call(order, client: Client.new) = new(client).call(order)

      def initialize(client) = @client = client

      def call(order)
        response = @client.create_order(payload(order), request_id: order.id)
        order.update!(paypal_order_id: response.fetch("id"))
        response
      end

      private
        def payload(order)
          product = order.product
          {
            intent: "CAPTURE",
            purchase_units: [ {
              reference_id: order.id, custom_id: order.id,
              description: product.name.truncate(127),
              amount: { currency_code: order.currency, value: format("%.2f", order.amount) }
            } ],
            payment_source: { paypal: { experience_context: {
              shipping_preference: "NO_SHIPPING", user_action: "PAY_NOW", brand_name: "DevBatista",
              return_url: "#{product.public_url}#buy", cancel_url: "#{product.public_url}#buy"
            } } }
          }
        end
    end
  end
end
