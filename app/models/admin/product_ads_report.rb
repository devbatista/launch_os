module Admin
  # Números das campanhas da Meta vinculadas a um produto (spec 16), para o show do produto: vida toda e
  # últimos 7 dias, mais a tabela por anúncio (vida toda). Gasto, impressões, cliques e LP views vêm do
  # Insights (`AdInsight` das campanhas do produto); checkouts e vendas vêm dos pedidos, que são a verdade.
  #
  # Pedidos "da Meta" = `utm_source` dos parâmetros de URL dos anúncios; por anúncio, `ad_name` = `utm_content`.
  # "Vida toda" começa no primeiro dia com dado das campanhas vinculadas. Datas no fuso da conta de anúncios.
  class ProductAdsReport
    META_UTM_SOURCE = "facebook" # docs/conteudo/criativos.md
    RECENT_DAYS = 7

    attr_reader :product

    def initialize(product)
      @product = product
    end

    def campaigns = @campaigns ||= product.ad_campaigns.order(:created_at).to_a
    def available_campaigns = @available_campaigns ||= AdCampaign.unassigned.recent.to_a

    def data? = @data ||= insights.exists?
    def synced_at = @synced_at ||= insights.maximum(:updated_at)
    def currency = @currency ||= insights.pick(:currency) || "BRL"
    def first_date = @first_date ||= insights.minimum(:date)

    def lifetime = @lifetime ||= stats(first_date && (first_date..today))
    def recent = @recent ||= stats((today - (RECENT_DAYS - 1))..today)

    # [{ name:, spend_cents:, impressions:, link_clicks:, ctr:, landing_page_views:, meta_purchases:,
    #    checkouts:, sales:, cac_cents: }, …] na vida toda, do maior gasto para o menor.
    def ads
      @ads ||= begin
        orders = first_date ? meta_orders(first_date..today) : Order.none
        checkouts = orders.group(:utm_content).count
        sales = orders.paid.group(:utm_content).count
        insights.group(:ad_name)
                .pluck(:ad_name, Arel.sql("SUM(spend_cents)"), Arel.sql("SUM(impressions)"), Arel.sql("SUM(link_clicks)"),
                       Arel.sql("SUM(landing_page_views)"), Arel.sql("SUM(purchases)"))
                .map do |name, spend, impressions, clicks, lp_views, purchases|
                  sold = sales[name].to_i
                  { name:, spend_cents: spend, impressions:, link_clicks: clicks, ctr: ctr(clicks, impressions),
                    landing_page_views: lp_views, meta_purchases: purchases, checkouts: checkouts[name].to_i,
                    sales: sold, cac_cents: cac(spend, sold) }
                end
                .sort_by { |row| -row[:spend_cents] }
      end
    end

    private
      def today = Time.current.in_time_zone(MetaAds::TIME_ZONE).to_date

      def insights = AdInsight.where(meta_campaign_id: product.ad_campaigns.select(:meta_campaign_id))

      def meta_orders(dates)
        range = dates.first.in_time_zone(MetaAds::TIME_ZONE)..dates.last.in_time_zone(MetaAds::TIME_ZONE).end_of_day
        product.orders.where(utm_source: META_UTM_SOURCE, created_at: range)
      end

      # { spend_cents:, impressions:, link_clicks:, ctr:, landing_page_views:, meta_purchases:, checkouts:,
      #   sales:, cac_cents:, roas: } — tudo zero/nil quando não há dados.
      def stats(dates)
        return { spend_cents: 0, impressions: 0, link_clicks: 0, ctr: nil, landing_page_views: 0, meta_purchases: 0,
                 checkouts: 0, sales: 0, cac_cents: nil, roas: nil } if dates.nil?

        spend, impressions, clicks, lp_views, purchases =
          insights.where(date: dates).pick(*%w[spend_cents impressions link_clicks landing_page_views purchases].map { |c| Arel.sql("COALESCE(SUM(#{c}), 0)") })
        orders = meta_orders(dates)
        paid = orders.paid
        sales = paid.count
        { spend_cents: spend, impressions:, link_clicks: clicks, ctr: ctr(clicks, impressions), landing_page_views: lp_views,
          meta_purchases: purchases, checkouts: orders.count, sales:, cac_cents: cac(spend, sales), roas: roas(paid, spend) }
      end

      def cac(spend, sales) = sales.zero? ? nil : (spend.to_d / sales).round.to_i

      # Recebido líquido no PayPal (já na moeda da conta, spec 18) ÷ gasto. nil sem gasto ou quando algum pedido
      # pago ainda não tem o valor recebido nessa moeda — melhor nada que um ROAS errado.
      def roas(paid, spend)
        return nil if spend.zero?
        return nil if paid.where(paypal_receivable_cents: nil).or(paid.where.not(paypal_receivable_currency: currency)).exists?

        (paid.sum(:paypal_receivable_cents).to_d / spend).round(2)
      end

      # CTR com duas casas: a referência da campanha é 1% e a diferença entre 0,9% e 1,4% importa.
      def ctr(clicks, impressions)
        return nil if impressions.to_i.zero?

        (clicks.to_d / impressions * 100).round(2)
      end
  end
end
