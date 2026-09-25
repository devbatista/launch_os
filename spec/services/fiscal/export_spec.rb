require "rails_helper"
require "csv"

# CSV das vendas do mês para a contabilidade (spec 18, fase A).
RSpec.describe Fiscal::Export do
  subject(:rows) { CSV.parse(described_class.call(year: 2026, month: 10)) }

  let(:zone) { ActiveSupport::TimeZone["America/Sao_Paulo"] }
  let(:product) { create(:product, name: "21-Day Procrastination Reset") }

  def paid_order(paid_at:, **attrs)
    create(:order, :paid, product:, paid_at:, payment_fee_cents: 88, net_amount_cents: 1402,
                          paypal_exchange_rate: 4.89294565, paypal_receivable_cents: 6860,
                          paypal_receivable_currency: "BRL", payer_country: "US", **attrs)
  end

  it "lista as vendas do mês em ordem de pagamento, com bruto, tarifa e líquido separados" do
    paid_order(paid_at: zone.local(2026, 10, 20, 9), payer_name: "John Smith", payer_email: "john@example.com")
    paid_order(paid_at: zone.local(2026, 10, 2, 9), payer_name: "Ana Souza", payer_email: "ana@example.com")

    expect(rows.first).to start_with("order_id", "paid_at", "status", "product")
    expect(rows[1]).to include("Ana Souza", "ana@example.com", "US", "USD", "14.90", "0.88", "14.02", "68.60", "BRL")
    expect(rows[2]).to include("John Smith")
    expect(rows[1][1]).to start_with("2026-10-02 09:00") # America/Sao_Paulo, não UTC
  end

  it "ignora pedidos de outros meses e os que nunca foram pagos" do
    paid_order(paid_at: zone.local(2026, 10, 31, 23, 59))
    paid_order(paid_at: zone.local(2026, 11, 1, 0, 1))
    paid_order(paid_at: zone.local(2026, 9, 30, 23, 59))
    create(:order, product:) # pending

    expect(rows.size).to eq(3) # cabeçalho + 1 venda + TOTAL
  end

  it "soma os totais só das vendas válidas, mas mantém reembolso e disputa listados" do
    paid_order(paid_at: zone.local(2026, 10, 5, 9))
    paid_order(paid_at: zone.local(2026, 10, 6, 9), status: :refunded, refunded_at: zone.local(2026, 10, 7, 9))
    paid_order(paid_at: zone.local(2026, 10, 8, 9), status: :disputed, disputed_at: zone.local(2026, 10, 9, 9))

    total = rows.last
    expect(rows.size).to eq(5)
    expect(total[0]).to eq("TOTAL")
    expect(total[2]).to eq("1 venda(s) · 1 reembolso(s) · 1 disputa(s)")
    expect(total[9]).to eq("14.90")  # bruto só da venda válida
    expect(total[10]).to eq("0.88")  # tarifa
    expect(total[11]).to eq("14.02") # líquido
  end

  it "deixa as colunas vazias quando o pedido ainda não tem o breakdown" do
    create(:order, :paid, product:, paid_at: zone.local(2026, 10, 3, 9), payment_fee_cents: nil, net_amount_cents: nil)

    expect(rows[1][10]).to be_nil
    expect(rows.last[10]).to eq("0.00")
  end
end
