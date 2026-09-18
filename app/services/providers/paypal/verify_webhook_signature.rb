module Providers
  module Paypal
    # Verifica a assinatura de um webhook via API do PayPal (spec 07). Em development, sem túnel,
    # PAYPAL_WEBHOOK_SKIP_VERIFY=true pula a verificação — nunca em produção (config/initializers/paypal.rb).
    class VerifyWebhookSignature
      SIGNATURE_HEADERS = %w[PAYPAL-AUTH-ALGO PAYPAL-CERT-URL PAYPAL-TRANSMISSION-ID PAYPAL-TRANSMISSION-SIG PAYPAL-TRANSMISSION-TIME].freeze

      def self.call(headers:, body:, client: nil) = new(client).call(headers:, body:)

      def initialize(client) = @client = client

      # headers: Hash com os PAYPAL-* (ou ActionDispatch::Http::Headers); body: corpo bruto (String).
      def call(headers:, body:)
        return true if skip?

        signature = SIGNATURE_HEADERS.index_with { |h| headers[h] }
        return false if signature.values.any?(&:blank?)

        (@client || Client.new).verify_webhook_signature(headers: signature, body:)
      rescue JSON::ParserError
        false
      end

      def self.skip? = Rails.env.development? && ENV["PAYPAL_WEBHOOK_SKIP_VERIFY"] == "true"
      delegate :skip?, to: :class
    end
  end
end
