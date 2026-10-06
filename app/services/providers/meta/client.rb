module Providers
  module Meta
    # Único ponto que fala com a Graph API / Marketing API da Meta (spec 16), via Faraday — sem SDK.
    # Por ora só leitura (`ads_read`): Insights por anúncio e por dia, estado de campanhas/conjuntos/anúncios
    # e alcance/frequência do período. Token de System User do portfólio; conta própria dispensa App Review
    # (standard access a `ads_read`/`ads_management`).
    # Referências: https://developers.facebook.com/docs/marketing-api/reference/ad-account/insights/,
    # .../reference/ad-campaign-group/ (campanha), .../reference/ad-campaign/ (conjunto), .../reference/adgroup/
    # (anúncio) e https://developers.facebook.com/docs/graph-api/overview/rate-limiting/
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
      # Orçamentos vêm em centavos da moeda da conta (numeric string); `learning_stage_info.status` é
      # LEARNING, SUCCESS ou FAIL; `issues_info` traz error_summary/error_message do que trava a entrega.
      CAMPAIGN_FIELDS = %w[id name effective_status objective bid_strategy daily_budget lifetime_budget
                           start_time stop_time issues_info].freeze
      AD_SET_FIELDS = %w[id name campaign_id effective_status optimization_goal daily_budget lifetime_budget
                         learning_stage_info start_time end_time issues_info].freeze
      AD_FIELDS = %w[id name adset_id campaign_id effective_status issues_info created_time].freeze
      # Alcance é deduplicado no período (não soma por dia), por isso vem numa chamada sem `time_increment`.
      # Os rankings de relevância só existem por anúncio e chegam como string crua.
      REACH_FIELDS = {
        "campaign" => %w[campaign_id reach frequency],
        "ad" => %w[ad_id campaign_id reach frequency quality_ranking engagement_rate_ranking conversion_rate_ranking]
      }.freeze

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
        get_all("insights", level: "ad", time_increment: 1, fields: INSIGHTS_FIELDS.join(","),
                            time_range: time_range(since, until_date), use_account_attribution_setting: true)
      end

      # GET /act_{id}/insights agregado no período (um registro por campanha ou anúncio), para alcance,
      # frequência e rankings. `level`: "campaign" ou "ad".
      def reach_insights(level:, since:, until_date:)
        get_all("insights", level:, fields: REACH_FIELDS.fetch(level).join(","),
                            time_range: time_range(since, until_date), use_account_attribution_setting: true)
      end

      # GET /act_{id}/campaigns, /adsets e /ads com o estado atual de cada objeto. Hashes crus da API.
      def campaigns = get_all("campaigns", fields: CAMPAIGN_FIELDS.join(","))
      def ad_sets = get_all("adsets", fields: AD_SET_FIELDS.join(","))
      def ads = get_all("ads", fields: AD_FIELDS.join(","))

      private
        def time_range(since, until_date) = { since: since.iso8601, until: until_date.iso8601 }.to_json

        # GET numa aresta da conta seguindo `paging.next` até o fim.
        def get_all(edge, **params)
          body = request { @http.get("#{@version}/act_#{@ad_account_id}/#{edge}", params.merge(limit: PAGE_LIMIT, access_token: @access_token)) }
          rows = Array(body["data"])

          pages = 1
          while (next_url = body.dig("paging", "next"))
            raise ApiError.new("Meta: paginação de #{edge} passou de #{MAX_PAGES} páginas", code: nil, status: nil) if (pages += 1) > MAX_PAGES

            body = request { @http.get(next_url) }
            rows.concat(Array(body["data"]))
          end
          rows
        end

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
