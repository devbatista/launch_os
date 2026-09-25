module Admin
  # Métricas do painel (spec 11): funil LP → checkout → venda, receita, entregas, vendas por campanha e
  # alertas, para um período e (opcionalmente) um produto. Objeto de consulta sem estado além dos
  # filtros; cada método é uma query simples sobre índices existentes. Sem gráficos, sem CAC/ROAS.
  #
  # Semântica de coorte: pedidos, vendas e reembolsos são os dos pedidos **criados** no período — assim
  # as taxas comparam visitantes, checkouts e vendas do mesmo grupo. Alertas e últimos pedidos ignoram
  # o período (são "agora").
  class Dashboard
    PERIODS = { "today" => "Hoje", "7d" => "7 dias", "30d" => "30 dias", "custom" => "Período" }.freeze
    DEFAULT_PERIOD = "7d"
    TIME_ZONE = "America/Sao_Paulo"
    ALERT_WINDOW = 24.hours
    MESSAGE_ALERT_WINDOW = 7.days

    # Estimativa da taxa do PayPal (spec 07), usada só enquanto a captura não trouxe o valor real:
    # desde a spec 18 o `seller_receivable_breakdown` grava a tarifa no próprio pedido.
    def self.fee_percent = ENV.fetch("PAYPAL_FEE_PERCENT", "4.4").to_d
    def self.fee_fixed_cents = ENV.fetch("PAYPAL_FEE_FIXED_CENTS", "30").to_i

    attr_reader :period, :range, :product_id

    def initialize(period: nil, from: nil, to: nil, product_id: nil)
      @period = PERIODS.key?(period) ? period : DEFAULT_PERIOD
      @product_id = product_id.presence
      @range = build_range(from, to)
    end

    def product = @product ||= product_id && Product.find_by(id: product_id)

    # --- Funil ---------------------------------------------------------------------------------

    def visits = @visits ||= visits_scope.count
    def unique_visitors = @unique_visitors ||= visits_scope.where.not(visitor_id: nil).distinct.count(:visitor_id)
    def checkouts = @checkouts ||= orders_scope.count
    def sales = @sales ||= paid_scope.count
    def gross_cents = @gross_cents ||= paid_scope.sum(:amount_cents)

    # Tarifa real dos pedidos que já têm o breakdown da captura + estimativa para o restante (spec 18).
    def fee_cents = real_fee_cents + estimated_fee_cents
    def net_cents = gross_cents - fee_cents

    # Quantos pedidos pagos do período ainda dependem de estimativa (o card avisa quando > 0).
    def estimated_fee_orders = @estimated_fee_orders ||= paid_scope.where(payment_fee_cents: nil).count

    def refunds = @refunds ||= orders_scope.refunded.count
    def refunded_cents = @refunded_cents ||= orders_scope.refunded.sum(:amount_cents)
    def disputed = @disputed ||= orders_scope.disputed.count
    def pending = @pending ||= orders_scope.pending.count

    # Taxas em porcentagem (0–100) ou nil quando o denominador é zero.
    def visitor_to_checkout_rate = rate(checkouts, unique_visitors)
    def checkout_to_sale_rate = rate(sales, checkouts)
    def conversion_rate = rate(sales, unique_visitors)

    # --- Entregas (mensagens de order_delivery dos pedidos do período) -------------------------

    def email_delivery
      @email_delivery ||= delivery_stats(delivery_logs.channel_email, ok: %w[sent delivered read])
    end

    def whatsapp_delivery
      @whatsapp_delivery ||= delivery_stats(delivery_logs.channel_whatsapp, ok: %w[delivered read])
    end

    # --- Campanhas -----------------------------------------------------------------------------

    def sales_by_campaign = @sales_by_campaign ||= sales_by(:utm_campaign)
    def sales_by_content = @sales_by_content ||= sales_by(:utm_content)

    # --- Fora do período -----------------------------------------------------------------------

    def latest_orders
      @latest_orders ||= Order.includes(:product, :client).recent.then { |s| product_id ? s.where(product_id:) : s }.limit(10)
    end

    def failed_webhooks = @failed_webhooks ||= WebhookEvent.failed.where(created_at: ALERT_WINDOW.ago..).count
    def failed_messages = @failed_messages ||= MessageLog.where(status: %w[failed undelivered], created_at: MESSAGE_ALERT_WINDOW.ago..).count
    def open_disputes = @open_disputes ||= Order.disputed.count
    def alerts? = failed_webhooks.positive? || failed_messages.positive? || open_disputes.positive?

    private
      def build_range(from, to)
        now = Time.current.in_time_zone(TIME_ZONE)
        case period
        when "today" then now.beginning_of_day..now.end_of_day
        when "30d" then (now - 29.days).beginning_of_day..now.end_of_day
        when "custom"
          from_date = parse_date(from) || now.to_date - 6
          to_date = parse_date(to) || now.to_date
          from_date, to_date = to_date, from_date if from_date > to_date
          from_date.in_time_zone(TIME_ZONE).beginning_of_day..to_date.in_time_zone(TIME_ZONE).end_of_day
        else (now - 6.days).beginning_of_day..now.end_of_day
        end
      end

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end

      def visits_scope
        scope = PageVisit.humans.where(created_at: range)
        product_id ? scope.where(product_id:) : scope
      end

      def orders_scope
        scope = Order.where(created_at: range)
        product_id ? scope.where(product_id:) : scope
      end

      def paid_scope = orders_scope.paid

      def real_fee_cents = @real_fee_cents ||= paid_scope.where.not(payment_fee_cents: nil).sum(:payment_fee_cents)

      def estimated_fee_cents
        pending = paid_scope.where(payment_fee_cents: nil)
        ((pending.sum(:amount_cents) * self.class.fee_percent / 100) + self.class.fee_fixed_cents * pending.count).round
      end

      def delivery_logs = MessageLog.template_order_delivery.where(order_id: orders_scope.select(:id))

      # { total:, ok:, failed:, rate: } — rate = ok / total em %, nil sem mensagens.
      def delivery_stats(scope, ok:)
        total = scope.count
        ok_count = scope.where(status: ok).count
        failed = scope.where(status: %w[failed undelivered]).count
        { total:, ok: ok_count, failed:, rate: rate(ok_count, total) }
      end

      # [[valor, vendas, receita_cents], …] ordenado por vendas; nil vira "(direto)" na view.
      def sales_by(field)
        paid_scope.group(field).pluck(field, Arel.sql("COUNT(*)"), Arel.sql("SUM(amount_cents)"))
                  .sort_by { |_, count, cents| [ -count, -cents ] }.first(10)
      end

      def rate(numerator, denominator)
        return nil if denominator.to_i.zero?

        (numerator.to_d / denominator * 100).round(1)
      end
  end
end
