require "csv"

module Fiscal
  # CSV das vendas de um mês para a contabilidade (spec 18). É o insumo da NF-e consolidada: uma linha
  # por venda, com bruto, tarifa e líquido separados, mais uma linha TOTAL ao final.
  #
  # Competência: `paid_at` convertido para America/Sao_Paulo — regra ainda a confirmar com a
  # contabilidade (spec 18, "Perguntas abertas"), por isso mora aqui e não espalhada pelo código.
  #
  # Entram os pedidos que foram pagos em algum momento do mês (inclusive os reembolsados depois, com a
  # data do reembolso na linha): o relatório mostra a venda e o evento, sem decidir o ajuste fiscal.
  #
  # Ainda NÃO converte para BRL por PTAX (fase C): as colunas do PayPal são a conversão comercial do
  # gateway, servem para conciliar o extrato e não são base da nota.
  class Export
    TIME_ZONE = "America/Sao_Paulo"
    HEADERS = %w[
      order_id paid_at status product customer_name customer_email country ip
      currency gross payment_fee net paypal_exchange_rate paypal_receivable paypal_receivable_currency
      refunded_at disputed_at utm_campaign utm_content
    ].freeze

    def self.call(year:, month:) = new(year:, month:).call

    def initialize(year:, month:)
      @year = Integer(year)
      @month = Integer(month)
    end

    def call
      CSV.generate do |csv|
        csv << HEADERS
        orders.each { |order| csv << row(order) }
        csv << totals_row
      end
    end

    def orders
      @orders ||= Order.includes(:product, :client).where(paid_at: range).order(:paid_at).to_a
    end

    def range
      zone = ActiveSupport::TimeZone[TIME_ZONE]
      start = zone.local(@year, @month, 1)
      start...start.next_month
    end

    private
      def row(order)
        [
          order.id, in_zone(order.paid_at), order.status, order.product.name,
          order.payer_name, order.payer_email, order.payer_country || order.client&.country, order.ip_address,
          order.currency, decimal(order.amount_cents), decimal(order.payment_fee_cents), decimal(order.net_amount_cents),
          order.paypal_exchange_rate, decimal(order.paypal_receivable_cents), order.paypal_receivable_currency,
          in_zone(order.refunded_at), in_zone(order.disputed_at), order.utm_campaign, order.utm_content
        ]
      end

      # Totais só dos pedidos que continuam válidos (reembolsado e disputado saem do somatório, mas
      # seguem listados acima). O tratamento fiscal do reembolso depende de regra contábil (spec 18).
      def totals_row
        valid = orders.select(&:paid?)
        row = Array.new(HEADERS.size)
        row[0] = "TOTAL"
        row[2] = "#{valid.size} venda(s) · #{orders.count(&:refunded?)} reembolso(s) · #{orders.count(&:disputed?)} disputa(s)"
        row[8] = valid.first&.currency
        row[9] = decimal(valid.sum(&:amount_cents))
        row[10] = decimal(valid.sum { |o| o.payment_fee_cents.to_i })
        row[11] = decimal(valid.sum { |o| o.net_amount_cents.to_i })
        row[13] = decimal(valid.sum { |o| o.paypal_receivable_cents.to_i })
        row[14] = valid.filter_map(&:paypal_receivable_currency).uniq.join("/").presence
        row
      end

      def decimal(cents) = cents && format("%.2f", cents.to_d / 100)

      def in_zone(time) = time&.in_time_zone(TIME_ZONE)&.strftime("%Y-%m-%d %H:%M:%S")
  end
end
