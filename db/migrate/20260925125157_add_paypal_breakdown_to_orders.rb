# Valores reais da captura do PayPal (spec 18, fase A). O `seller_receivable_breakdown` do capture já
# chegava e ficava guardado em `webhook_events.payload`; aqui ele passa a colunas, para o admin e o
# relatório fiscal pararem de estimar a tarifa. Tudo nullable: pedido antigo (ou capture PENDING) fica
# sem os valores até o backfill (`bin/rails fiscal:backfill_paypal`).
#
# A tarifa NUNCA reduz o faturamento bruto — ela existe só para a receita líquida e a conciliação.
class AddPaypalBreakdownToOrders < ActiveRecord::Migration[8.1]
  def change
    change_table :orders, bulk: true do |t|
      t.integer :payment_fee_cents       # tarifa do PayPal, na moeda do pedido
      t.integer :net_amount_cents        # bruto − tarifa, na moeda do pedido
      t.decimal :paypal_exchange_rate, precision: 18, scale: 8 # conversão comercial do PayPal, não é PTAX
      t.integer :paypal_receivable_cents # valor creditado na conta, já convertido pelo PayPal
      t.string  :paypal_receivable_currency, limit: 3
      t.string  :payer_country, limit: 2 # país do pagador no momento da venda (Client#country pode mudar)
    end
  end
end
