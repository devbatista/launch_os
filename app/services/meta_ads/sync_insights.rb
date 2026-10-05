module MetaAds
  # Puxa o Insights por anúncio e por dia e regrava `AdInsight` (upsert por meta_ad_id + date).
  # A janela padrão reprocessa os últimos LOOKBACK_DAYS: a Meta ainda atribui conversões a dias passados
  # (janela de 7 dias após o clique) e só congela os números depois de 28 dias.
  #
  # Ações lidas do Pixel (`offsite_conversion.fb_pixel_*`) e não as variantes `omni_*`, que somam outros
  # canais — o único que temos é o Pixel.
  class SyncInsights
    LOOKBACK_DAYS = 7
    LANDING_PAGE_VIEW = "landing_page_view".freeze
    INITIATE_CHECKOUT = "offsite_conversion.fb_pixel_initiate_checkout".freeze
    PURCHASE = "offsite_conversion.fb_pixel_purchase".freeze

    def self.call(...) = new(...).call

    def initialize(since: nil, until_date: nil, client: nil)
      today = Time.current.in_time_zone(TIME_ZONE).to_date
      @until_date = until_date || today
      @since = since || @until_date - LOOKBACK_DAYS
      @client = client || Providers::Meta::Client.new
    end

    # Devolve quantas linhas (anúncio × dia) foram gravadas.
    def call
      raise ArgumentError, "since (#{@since}) depois de until (#{@until_date})" if @since > @until_date

      rows = @client.ad_insights(since: @since, until_date: @until_date).map { |row| attributes(row) }
      AdInsight.upsert_all(rows, unique_by: %i[meta_ad_id date]) if rows.any?
      Rails.logger.info { "[ads] insights #{@since}..#{@until_date}: #{rows.size} linha(s)" }
      rows.size
    end

    private
      def attributes(row)
        actions = Array(row["actions"]).to_h { |a| [ a["action_type"], a["value"] ] }
        {
          date: Date.iso8601(row.fetch("date_start")),
          meta_ad_id: row.fetch("ad_id"),
          ad_name: row.fetch("ad_name"),
          meta_campaign_id: row["campaign_id"],
          campaign_name: row["campaign_name"],
          spend_cents: (row["spend"].to_d * 100).round.to_i,
          currency: row.fetch("account_currency"),
          impressions: row["impressions"].to_i,
          link_clicks: row["inline_link_clicks"].to_i,
          landing_page_views: count(actions[LANDING_PAGE_VIEW]),
          initiate_checkouts: count(actions[INITIATE_CHECKOUT]),
          purchases: count(actions[PURCHASE])
        }
      end

      def count(value) = value.to_d.round.to_i
  end
end
