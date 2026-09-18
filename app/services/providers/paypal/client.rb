module Providers
  module Paypal
    # Único ponto que fala com a REST API do PayPal (Orders v2 + verificação de webhook) — spec 07.
    # Faraday sem SDK; token OAuth em cache (Redis via Rails.cache); erros do transporte viram
    # Providers::TransientError (timeout, 5xx, 429) ou Providers::PermanentError (4xx) com o
    # `name`/`details` do corpo. Nunca loga corpo de resposta (tem email/nome do pagador).
    class Client
      BASE = { "sandbox" => "https://api-m.sandbox.paypal.com", "live" => "https://api-m.paypal.com" }.freeze
      OPEN_TIMEOUT = 5
      TIMEOUT = 10
      TOKEN_SAFETY_MARGIN = 60 # segundos descontados do expires_in antes de renovar

      # 4xx com o `name`/`details` que o PayPal devolve (INVALID_REQUEST, UNPROCESSABLE_ENTITY, ORDER_ALREADY_CAPTURED…).
      class ApiError < Providers::PermanentError
        attr_reader :status, :error_name, :details

        def initialize(status:, error_name:, details: [], message: nil)
          @status, @error_name, @details = status, error_name, Array(details)
          super(message || "PayPal #{status} #{error_name}")
        end

        def issue?(name) = error_name == name || details.any? { |d| d["issue"] == name }
      end

      def initialize(env: ENV.fetch("PAYPAL_ENV", "sandbox"), client_id: ENV.fetch("PAYPAL_CLIENT_ID"),
                     client_secret: ENV.fetch("PAYPAL_CLIENT_SECRET"), http: nil, cache: Rails.cache)
        @env = env
        @base = BASE.fetch(env) { raise ArgumentError, "PAYPAL_ENV must be sandbox or live (got #{env.inspect})" }
        @client_id, @client_secret, @cache = client_id, client_secret, cache
        @http = http || build_http
      end

      # POST /v1/oauth2/token (client_credentials), cacheado por expires_in - 60 s.
      def access_token
        cached = @cache.read(token_cache_key)
        return cached if cached

        response = handle_transport do
          @http.post("/v1/oauth2/token", "grant_type=client_credentials") do |req|
            req.headers["Content-Type"] = "application/x-www-form-urlencoded"
            req.headers["Authorization"] = basic_auth
          end
        end
        body = ensure_success!(response, "oauth2/token")
        token = body.fetch("access_token")
        ttl = body.fetch("expires_in", 3600).to_i - TOKEN_SAFETY_MARGIN
        @cache.write(token_cache_key, token, expires_in: [ ttl, 60 ].max)
        token
      end

      # POST /v2/checkout/orders — `request_id` é o PayPal-Request-Id (idempotência): usamos order.id.
      def create_order(body, request_id:)
        post_json("/v2/checkout/orders", body, request_id:)
      end

      # POST /v2/checkout/orders/:id/capture — request_id "capture-#{order.id}".
      def capture_order(id, request_id:)
        post_json("/v2/checkout/orders/#{id}/capture", {}, request_id:)
      end

      # GET /v2/checkout/orders/:id
      def get_order(id)
        response = handle_transport { @http.get("/v2/checkout/orders/#{id}") { |req| req.headers["Authorization"] = bearer } }
        ensure_success!(response, "get_order")
      end

      # POST /v1/notifications/verify-webhook-signature → true/false. `body` é o corpo bruto do webhook
      # (parseado aqui, sem reserializar) e `headers` os PAYPAL-* da requisição.
      def verify_webhook_signature(headers:, body:, webhook_id: ENV.fetch("PAYPAL_WEBHOOK_ID"))
        payload = {
          auth_algo: headers["PAYPAL-AUTH-ALGO"], cert_url: headers["PAYPAL-CERT-URL"],
          transmission_id: headers["PAYPAL-TRANSMISSION-ID"], transmission_sig: headers["PAYPAL-TRANSMISSION-SIG"],
          transmission_time: headers["PAYPAL-TRANSMISSION-TIME"], webhook_id:, webhook_event: JSON.parse(body)
        }
        result = post_json("/v1/notifications/verify-webhook-signature", payload)
        result["verification_status"] == "SUCCESS"
      end

      # PATCH /v1/notifications/webhooks/:id — troca a URL de entrega. Só para dev (bin/tunnel): o quick
      # tunnel do Cloudflare muda de endereço a cada subida; em produção a URL é fixa.
      def update_webhook_url(url, webhook_id: ENV.fetch("PAYPAL_WEBHOOK_ID"))
        response = handle_transport do
          @http.patch("/v1/notifications/webhooks/#{webhook_id}", [ { op: "replace", path: "/url", value: url } ]) do |req|
            req.headers["Authorization"] = bearer
          end
        end
        ensure_success!(response, "update_webhook_url")
      end

      private
        def build_http
          Faraday.new(url: @base) do |f|
            f.request :json
            f.response :json, content_type: /\bjson$/
            f.options.open_timeout = OPEN_TIMEOUT
            f.options.timeout = TIMEOUT
            f.adapter Faraday.default_adapter
          end
        end

        def post_json(path, body, request_id: nil)
          response = handle_transport do
            @http.post(path, body) do |req|
              req.headers["Authorization"] = bearer
              req.headers["PayPal-Request-Id"] = request_id if request_id
            end
          end
          ensure_success!(response, path)
        end

        def handle_transport
          yield
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
          raise Providers::TransientError, "PayPal unreachable: #{e.class}"
        end

        # 2xx → corpo (Hash); 5xx/429 → TransientError; demais 4xx → ApiError (PermanentError).
        def ensure_success!(response, label)
          status = response.status
          body = response.body.is_a?(Hash) ? response.body : {}
          Rails.logger.info { "[paypal] #{label} → #{status}" }
          return body if (200..299).cover?(status)

          raise Providers::TransientError, "PayPal #{label} responded #{status}" if status >= 500 || status == 429

          raise ApiError.new(status:, error_name: body["name"] || body["error"] || "HTTP_#{status}", details: body["details"],
                             message: "PayPal #{label} #{status}: #{body['name'] || body['error']} #{body['message'] || body['error_description']}".strip)
        end

        def bearer = "Bearer #{access_token}"
        def basic_auth = "Basic #{Base64.strict_encode64("#{@client_id}:#{@client_secret}")}"
        def token_cache_key = "paypal:#{@env}:#{@client_id}:access_token"
    end
  end
end
