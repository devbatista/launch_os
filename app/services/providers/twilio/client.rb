module Providers
  module Twilio
    # Único ponto que fala com a REST API da Twilio (spec 09), via Faraday — sem a gem twilio-ruby.
    # Envio de template de WhatsApp (Content API) e validação da assinatura dos webhooks.
    # Referências: https://www.twilio.com/docs/messaging/api/message-resource e
    # https://www.twilio.com/docs/usage/webhooks/webhooks-security
    class Client
      BASE = "https://api.twilio.com/2010-04-01".freeze
      OPEN_TIMEOUT = 5
      TIMEOUT = 10
      # 20429 rate limit, 20500 erro interno, 20503 indisponível — vale repetir. 21xxx (parâmetro) e
      # 63xxx (número sem WhatsApp, template rejeitado, fora da janela) são permanentes.
      TRANSIENT_CODES = [ 20429, 20500, 20503 ].freeze

      class ApiError < Providers::PermanentError
        attr_reader :code, :status

        def initialize(message, code:, status:)
          @code, @status = code, status
          super(message)
        end
      end

      def initialize(account_sid: ENV.fetch("TWILIO_ACCOUNT_SID"), auth_token: ENV.fetch("TWILIO_AUTH_TOKEN"),
                     from: ENV.fetch("TWILIO_WHATSAPP_FROM"), http: nil)
        @account_sid, @auth_token, @from = account_sid, auth_token, from
        @http = http || build_http
      end

      # POST /Accounts/{sid}/Messages.json (form-encoded, Basic Auth). `to` em E.164; `variables` é o hash
      # {"1" => ..., "2" => ...} do Content Template. Devolve o SID da mensagem (status inicial "queued").
      def send_template_message(to:, content_sid:, variables:, status_callback:)
        response = handle_transport do
          @http.post("Accounts/#{@account_sid}/Messages.json",
                     From: @from, To: "whatsapp:#{to}", ContentSid: content_sid,
                     ContentVariables: variables.to_json, StatusCallback: status_callback)
        end
        body = response.body.is_a?(Hash) ? response.body : {}
        return body.fetch("sid") if response.status == 201

        code = (body["code"] || body["error_code"]).to_i
        message = "Twilio #{code}: #{body["message"] || body["error_message"] || response.reason_phrase}"
        raise Providers::TransientError, message if response.status >= 500 || TRANSIENT_CODES.include?(code)
        raise ApiError.new(message, code:, status: response.status)
      end

      # X-Twilio-Signature = Base64(HMAC-SHA1(auth_token, url + params ordenados por chave, "chave" + "valor")).
      # `url` é a URL pública completa que a Twilio chamou; `params` os do corpo POST (sem os de rota).
      def valid_signature?(url:, params:, signature:)
        return false if signature.blank?

        data = url + params.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}#{v}" }.join
        expected = Base64.strict_encode64(OpenSSL::HMAC.digest("sha1", @auth_token, data))
        ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
      end

      private
        def build_http
          Faraday.new(url: BASE) do |f|
            f.request :url_encoded
            f.request :authorization, :basic, @account_sid, @auth_token
            f.response :json, content_type: /\bjson$/
            f.options.open_timeout = OPEN_TIMEOUT
            f.options.timeout = TIMEOUT
            f.adapter Faraday.default_adapter
          end
        end

        def handle_transport
          yield
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
          raise Providers::TransientError, "Twilio: #{e.class.name.demodulize}: #{e.message}"
        end
    end
  end
end
