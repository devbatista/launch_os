module Whatsapp
  # Monta as variáveis do Content Template `order_delivery` (spec 09) e chama o provider. O mesmo
  # template serve para entrega e reenvio. Devolve o SID da mensagem.
  #   {{1}} primeiro nome · {{2}} produto · {{3}} link /download/:token · {{4}} dias de validade
  class SendTemplateMessage
    include Rails.application.routes.url_helpers

    def self.call(order, client: Providers::Twilio::Client.new) = new(client).call(order)

    def initialize(client) = @client = client

    def call(order)
      token = order.download_token
      raise ArgumentError, "order #{order.id} has no active download token" unless token&.active?

      buyer = order.client
      @client.send_template_message(
        to: buyer.phone,
        content_sid: ENV.fetch("TWILIO_TEMPLATE_ORDER_DELIVERY_SID"),
        variables: { "1" => buyer.name.to_s.split.first.presence || "there", "2" => order.product.name,
                     "3" => download_url(token.token, **Delivery.url_options), "4" => DownloadToken.ttl.in_days.to_i.to_s },
        status_callback: webhooks_twilio_status_url(**Delivery.url_options)
      )
    end
  end
end
