module Providers
  module Meta
    # Único ponto que fala com a Graph API / Marketing API da Meta (spec 16), via Faraday — sem SDK.
    # Por ora só leitura: Insights por anúncio e por dia (`ads_read`). Token de System User do portfólio;
    # conta própria dispensa App Review (standard access a `ads_read`/`ads_management`).
    # Referências: https://developers.facebook.com/docs/marketing-api/reference/ad-account/insights/ e
    # https://developers.facebook.com/docs/graph-api/overview/rate-limiting/
    class Client
      BASE = "https://graph.facebook.com".freeze
      DEFAULT_VERSION = "v26.0".freeze
      OPEN_TIMEOUT = 5
      TIMEOUT = 30
      PAGE_LIMIT = 500
      MAX_PAGES = 50
      # 1 erro desconhecido, 4 limite do app, 17 limite do usuário, 613 limite customizado,
      # 80000 BUC Ads Insights, 80004 BUC Ads Management — vale repetir. 190 (token), 10/200 (permissão)
      # e 100 (parâmetro) são permanentes.
      TRANSIENT_CODES = [ 1, 4, 17, 613, 80_000, 80_004 ].freeze
      INSIGHTS_FIELDS = %w[ad_id ad_name campaign_id campaign_name date_start spend account_currency
                           impressions inline_link_clicks actions].freeze

      class ApiError < Providers::PermanentError
        attr_reader :code, :status

        def initialize(message, code:, status:)
          @code, @status = code, status
          super(message)
        end
      end

      def initialize(access_token: ENV.fetch("META_ACCESS_TOKEN"), ad_account_id: ENV.fetch("META_AD_ACCOUNT_ID"),
                     version: ENV.fetch("META_GRAPH_VERSION", DEFAULT_VERSION), http: nil)
        @access_token, @version = access_token, version
        @ad_account_id = ad_account_id.to_s.delete_prefix("act_")
        @http = http || build_http
      end

      # GET /act_{id}/insights no nível de anúncio, um registro por anúncio e dia (`time_increment=1`),
      # com a janela de atribuição configurada na conta. Segue `paging.next` até o fim. Dias sem
      # impressão não vêm. Devolve os hashes crus da API.
      def ad_insights(since:, until_date:)
        params = { level: "ad", time_increment: 1, fields: INSIGHTS_FIELDS.join(","), limit: PAGE_LIMIT,
                   time_range: { since: since.iso8601, until: until_date.iso8601 }.to_json,
                   use_account_attribution_setting: true, access_token: @access_token }
        body = request { @http.get("#{@version}/act_#{@ad_account_id}/insights", params) }
        rows = Array(body["data"])

        pages = 1
        while (next_url = body.dig("paging", "next"))
          raise ApiError.new("Meta: paginação do Insights passou de #{MAX_PAGES} páginas", code: nil, status: nil) if (pages += 1) > MAX_PAGES

          body = request { @http.get(next_url) }
          rows.concat(Array(body["data"]))
        end
        rows
      end

      private
        def build_http
          Faraday.new(url: BASE) do |f|
            f.response :json, content_type: /\bjson$/
            f.options.open_timeout = OPEN_TIMEOUT
            f.options.timeout = TIMEOUT
            f.adapter Faraday.default_adapter
          end
        end

        # Erro da Graph API: { "error": { "message", "type", "code", "error_subcode", "is_transient" } }.
        # A mensagem nunca leva o token (vai só na query da requisição, que não é registrada).
        def request
          response = yield
          body = response.body.is_a?(Hash) ? response.body : {}
          return body if response.success? && !body.key?("error")

          error = body["error"].is_a?(Hash) ? body["error"] : {}
          code = error["code"]&.to_i
          message = "Meta #{code || response.status}: #{error["message"] || response.reason_phrase}"
          transient = response.status >= 500 || response.status == 429 || error["is_transient"] == true || TRANSIENT_CODES.include?(code)
          raise Providers::TransientError, message if transient
          raise ApiError.new(message, code:, status: response.status)
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
          raise Providers::TransientError, "Meta: #{e.class.name.demodulize}: #{e.message}"
        end
    end
  end
end
