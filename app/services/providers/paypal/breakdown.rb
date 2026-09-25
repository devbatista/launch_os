module Providers
  module Paypal
    # Lê o `seller_receivable_breakdown` de um capture do PayPal (spec 18) e devolve os atributos do
    # `Order`. O bloco só existe em capture COMPLETED; em PENDING, ou em conta que recebe na mesma
    # moeda da venda, partes dele faltam — por isso o retorno traz apenas as chaves presentes.
    #
    #   "seller_receivable_breakdown" => {
    #     "gross_amount"      => { "value" => "14.90", "currency_code" => "USD" },
    #     "paypal_fee"        => { "value" => "0.88",  "currency_code" => "USD" },
    #     "net_amount"        => { "value" => "14.02", "currency_code" => "USD" },
    #     "exchange_rate"     => { "value" => "4.89294565", "source_currency" => "USD", "target_currency" => "BRL" },
    #     "receivable_amount" => { "value" => "68.60", "currency_code" => "BRL" } }
    class Breakdown
      def self.call(capture) = new.call(capture)

      def call(capture)
        data = capture&.dig("seller_receivable_breakdown")
        return {} if data.blank?

        {
          payment_fee_cents: cents(data["paypal_fee"]),
          net_amount_cents: cents(data["net_amount"]),
          paypal_exchange_rate: data.dig("exchange_rate", "value").presence&.to_d,
          paypal_receivable_cents: cents(data["receivable_amount"]),
          paypal_receivable_currency: data.dig("receivable_amount", "currency_code").presence
        }.compact
      end

      private
        # USD e BRL têm 2 casas; moeda de expoente diferente (JPY) exigiria tratar o expoente aqui.
        def cents(money)
          value = money&.dig("value").presence
          value && (value.to_d * 100).round
        end
    end
  end
end
