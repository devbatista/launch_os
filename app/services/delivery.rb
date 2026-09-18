# Entrega do produto ao comprador (spec 08 "DeliverOrderJob / Delivery::DeliverOrder" e spec 09):
# email sempre (canal principal e garantia de entrega); WhatsApp só com opt-in e TWILIO_ENABLED (2.7).
# Cada canal é um job independente — falha em um nunca afeta o outro nem o pedido.
module Delivery
  CHANNELS = %i[email whatsapp].freeze

  def self.whatsapp_enabled? = ENV["TWILIO_ENABLED"] == "true"

  # WhatsApp para este pedido: canal ligado, cliente com opt-in/telefone e sem opt-out.
  def self.whatsapp?(order) = whatsapp_enabled? && order.client&.whatsapp_deliverable? == true

  # URL pública da aplicação para links e callbacks gerados fora de um request (jobs). Em dev, para
  # a Twilio alcançar o callback, APP_HOST/APP_PROTOCOL precisam apontar para o túnel.
  def self.url_options
    host, port = ENV.fetch("APP_HOST", "localhost:3100").split(":")
    { host:, port: port&.to_i, protocol: ENV.fetch("APP_PROTOCOL", Rails.env.production? ? "https" : "http") }.compact
  end
end
