# Entrega do produto ao comprador (spec 08 "DeliverOrderJob / Delivery::DeliverOrder" e spec 09):
# email sempre (canal principal e garantia de entrega); WhatsApp só com opt-in e TWILIO_ENABLED (2.7).
# Cada canal é um job independente — falha em um nunca afeta o outro nem o pedido.
module Delivery
  CHANNELS = %i[email whatsapp].freeze

  def self.whatsapp_enabled? = ENV["TWILIO_ENABLED"] == "true"
end
