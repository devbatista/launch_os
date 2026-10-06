module MetaAds
  # Retrato da campanha de um produto para análise (skill `analisar-campanha`, `bin/rails 'ads:snapshot[slug]'`):
  # Insights gravados (`AdInsight` das campanhas vinculadas ao produto) cruzados com visitas e pedidos, por dia e
  # por anúncio, mais o estado ao vivo na Meta (status, orçamento, aprendizado, alcance, frequência, rankings).
  #
  # Só leitura e só agregados: nunca email, telefone, IP, nome ou id de pedido. Visitas e pedidos "da Meta" =
  # `utm_source` dos anúncios; por anúncio, `ad_name` = `utm_content`. Datas no fuso da conta de anúncios.
  # Se a Meta falhar, a parte do banco sai inteira e `live.error` explica o que faltou.
  class CampaignSnapshot
    META_UTM_SOURCE = Admin::ProductAdsReport::META_UTM_SOURCE
    INSIGHT_SUMS = %i[spend_cents impressions link_clicks landing_page_views initiate_checkouts purchases].freeze

    def self.call(...) = new(...).call

    def initialize(product, since: nil, until_date: nil, client: nil, live: MetaAds.insights_enabled?)
      @product, @client, @live = product, client, live
      @until_date = until_date || Time.current.in_time_zone(TIME_ZONE).to_date
      @since = since || product_insights.minimum(:date) || @until_date
      raise ArgumentError, "since (#{@since}) depois de until (#{@until_date})" if @since > @until_date
    end

    def call
      {
        generated_at: Time.current.iso8601,
        time_zone: TIME_ZONE,
        product: { slug: @product.slug, name: @product.name, status: @product.status,
                   price_cents: @product.price_cents, currency: @product.currency },
        period: { since: @since.iso8601, until: @until_date.iso8601, days: (@until_date - @since).to_i + 1 },
        sync: { last_synced_at: product_insights.maximum(:updated_at)&.iso8601,
                first_date: product_insights.minimum(:date)&.iso8601, last_date: product_insights.maximum(:date)&.iso8601 },
        ad_spend_currency: product_insights.pick(:currency),
        paypal_usd_brl_rate: paid_orders.where.not(paypal_exchange_rate: nil).average(:paypal_exchange_rate)&.round(4)&.to_f,
        campaigns: @product.ad_campaigns.order(:created_at).map { |c| { meta_campaign_id: c.meta_campaign_id, name: c.name } },
        unassigned_campaigns: unassigned_campaigns,
        totals: metrics(sums(insights), visits, meta_orders),
        daily: daily,
        ads: ads,
        orders: orders_summary,
        live: live
      }
    end

    private
      def campaign_ids = @campaign_ids ||= @product.ad_campaigns.pluck(:meta_campaign_id)
      def product_insights = AdInsight.where(meta_campaign_id: campaign_ids)
      def insights = product_insights.between(@since..@until_date)
      def range = @since.in_time_zone(TIME_ZONE)..@until_date.in_time_zone(TIME_ZONE).end_of_day
      def local_date(time) = time.in_time_zone(TIME_ZONE).to_date

      def meta_orders = @meta_orders ||= @product.orders.where(utm_source: META_UTM_SOURCE, created_at: range).pluck(:created_at, :utm_content, :status)
      def paid_orders = @product.orders.paid.where(utm_source: META_UTM_SOURCE, created_at: range)
      def visits = @visits ||= PageVisit.humans.where(product: @product, utm_source: META_UTM_SOURCE, created_at: range).pluck(:created_at, :utm_content, :visitor_id)

      def sums(scope)
        values = scope.pick(*INSIGHT_SUMS.map { |c| Arel.sql("COALESCE(SUM(#{c}), 0)") })
        INSIGHT_SUMS.zip(values).to_h
      end

      # Números da Meta + o que de fato aconteceu no site (visitas, pedidos criados = PayPal aberto, vendas pagas)
      # e as taxas já calculadas, para ninguém errar conta de cabeça. Taxa sem denominador = nil.
      def metrics(meta, visit_rows, order_rows)
        sales = order_rows.count { |row| row[2] == "paid" }
        visitors = visit_rows.map(&:last).compact.uniq.size
        checkouts = order_rows.size
        meta.merge(
          visits: visit_rows.size, unique_visitors: visitors, checkouts:, sales:,
          ctr: pct(meta[:link_clicks], meta[:impressions]),
          cpc_cents: ratio(meta[:spend_cents], meta[:link_clicks])&.round,
          cpm_cents: ratio(meta[:spend_cents] * 1000, meta[:impressions])&.round,
          lp_view_rate: pct(meta[:landing_page_views], meta[:link_clicks]),
          initiate_checkout_rate: pct(meta[:initiate_checkouts], meta[:landing_page_views]),
          checkout_per_visitor: pct(checkouts, visitors),
          sale_per_checkout: pct(sales, checkouts),
          cac_cents: ratio(meta[:spend_cents], sales)&.round
        )
      end

      def daily
        by_day = insights.group(:date).pluck(:date, *INSIGHT_SUMS.map { |c| Arel.sql("SUM(#{c})") })
                         .to_h { |date, *values| [ date, INSIGHT_SUMS.zip(values).to_h ] }
        visits_by_day = visits.group_by { |row| local_date(row[0]) }
        orders_by_day = meta_orders.group_by { |row| local_date(row[0]) }
        (@since..@until_date).map do |date|
          meta = by_day[date] || INSIGHT_SUMS.index_with(0)
          { date: date.iso8601 }.merge(metrics(meta, visits_by_day[date] || [], orders_by_day[date] || []))
        end
      end

      # Por anúncio (`ad_name` = `utm_content`), do maior gasto para o menor. Visitas e pedidos com
      # `utm_content` que não bate com nenhum anúncio do período vão em `unmatched` — sinal de UTM quebrada.
      def ads
        rows = insights.group(:ad_name).pluck(:ad_name, Arel.sql("ARRAY_AGG(DISTINCT meta_ad_id)"), *INSIGHT_SUMS.map { |c| Arel.sql("SUM(#{c})") })
        visits_by_ad = visits.group_by { |row| row[1] }
        orders_by_ad = meta_orders.group_by { |row| row[1] }
        names = rows.map(&:first)
        list = rows.map do |name, ad_ids, *values|
          { name:, meta_ad_ids: ad_ids }.merge(metrics(INSIGHT_SUMS.zip(values).to_h, visits_by_ad[name] || [], orders_by_ad[name] || []))
        end
        unmatched = {
          visits: visits_by_ad.except(*names).transform_values(&:size),
          checkouts: orders_by_ad.except(*names).transform_values(&:size)
        }
        { list: list.sort_by { |ad| -ad[:spend_cents] }, unmatched: }
      end

      def orders_summary
        all = @product.orders.where(created_at: range)
        {
          meta_by_status: meta_orders.group_by { |row| row[2] }.transform_values(&:size),
          meta_paid_by_country: paid_orders.group(:payer_country).count,
          other_sources_by_status: all.where.not(utm_source: META_UTM_SOURCE).or(all.where(utm_source: nil)).group(:status).count,
          meta_paid_received: paid_orders.where.not(paypal_receivable_cents: nil).group(:paypal_receivable_currency).sum(:paypal_receivable_cents),
          roas: roas
        }
      end

      # Recebido líquido no PayPal ÷ gasto, na moeda da conta de anúncios (mesma regra do ProductAdsReport):
      # nil sem gasto ou com pedido pago sem o valor recebido nessa moeda.
      def roas
        spend = insights.sum(:spend_cents)
        currency = product_insights.pick(:currency)
        return nil if spend.zero?
        return nil if paid_orders.where(paypal_receivable_cents: nil).or(paid_orders.where.not(paypal_receivable_currency: currency)).exists?

        (paid_orders.sum(:paypal_receivable_cents).to_d / spend).round(2).to_f
      end

      # Campanhas sem produto com gasto no período: dinheiro que não aparece em nenhum produto.
      def unassigned_campaigns
        AdInsight.between(@since..@until_date).where(meta_campaign_id: AdCampaign.unassigned.select(:meta_campaign_id))
                 .group(:meta_campaign_id, :campaign_name).sum(:spend_cents)
                 .map { |(id, name), spend| { meta_campaign_id: id, name:, spend_cents: spend } }
      end

      def live
        return { enabled: false } unless @live
        return { enabled: true, error: "nenhuma campanha vinculada ao produto" } if campaign_ids.empty?

        client = @client || Providers::Meta::Client.new
        mine = ->(rows, key) { rows.select { |row| campaign_ids.include?(row[key]) } }
        campaign_reach = client.reach_insights(level: "campaign", since: @since, until_date: @until_date).index_by { |r| r["campaign_id"] }
        ad_reach = client.reach_insights(level: "ad", since: @since, until_date: @until_date).index_by { |r| r["ad_id"] }

        {
          enabled: true,
          campaigns: mine.(client.campaigns, "id").map { |c| campaign(c, campaign_reach[c["id"]]) },
          ad_sets: mine.(client.ad_sets, "campaign_id").map { |s| ad_set(s) },
          ads: mine.(client.ads, "campaign_id").map { |a| ad(a, ad_reach[a["id"]]) }
        }
      rescue Providers::Error => e
        { enabled: true, error: e.message }
      end

      def campaign(row, reach)
        { id: row["id"], name: row["name"], effective_status: row["effective_status"], objective: row["objective"],
          bid_strategy: row["bid_strategy"], daily_budget_cents: cents(row["daily_budget"]),
          lifetime_budget_cents: cents(row["lifetime_budget"]), start_time: row["start_time"], stop_time: row["stop_time"],
          issues: issues(row), reach: reach&.dig("reach")&.to_i, frequency: reach&.dig("frequency")&.to_d&.round(2)&.to_f }
      end

      def ad_set(row)
        learning = row["learning_stage_info"] || {}
        { id: row["id"], name: row["name"], campaign_id: row["campaign_id"], effective_status: row["effective_status"],
          optimization_goal: row["optimization_goal"], daily_budget_cents: cents(row["daily_budget"]),
          lifetime_budget_cents: cents(row["lifetime_budget"]), learning_status: learning["status"],
          learning_conversions: learning["conversions"], start_time: row["start_time"], end_time: row["end_time"], issues: issues(row) }
      end

      def ad(row, reach)
        { id: row["id"], name: row["name"], adset_id: row["adset_id"], effective_status: row["effective_status"],
          created_time: row["created_time"], issues: issues(row), reach: reach&.dig("reach")&.to_i,
          frequency: reach&.dig("frequency")&.to_d&.round(2)&.to_f, quality_ranking: reach&.dig("quality_ranking"),
          engagement_rate_ranking: reach&.dig("engagement_rate_ranking"), conversion_rate_ranking: reach&.dig("conversion_rate_ranking") }
      end

      def issues(row) = Array(row["issues_info"]).map { |i| i.slice("level", "error_code", "error_summary", "error_message") }
      def cents(value) = value.presence&.to_i
      def ratio(num, den) = den.to_i.zero? ? nil : num.to_d / den
      def pct(num, den) = ratio(num, den)&.*(100)&.round(2)&.to_f
  end
end
