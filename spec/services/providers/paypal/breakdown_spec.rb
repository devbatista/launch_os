require "rails_helper"

# Valores reais da captura (spec 18, fase A).
RSpec.describe Providers::Paypal::Breakdown do
  let(:capture) do
    {
      "id" => "CAP-1",
      "seller_receivable_breakdown" => {
        "gross_amount" => { "value" => "14.90", "currency_code" => "USD" },
        "paypal_fee" => { "value" => "0.88", "currency_code" => "USD" },
        "net_amount" => { "value" => "14.02", "currency_code" => "USD" },
        "exchange_rate" => { "value" => "4.89294565", "source_currency" => "USD", "target_currency" => "BRL" },
        "receivable_amount" => { "value" => "68.60", "currency_code" => "BRL" }
      }
    }
  end

  it "converte tarifa, líquido e recebível para centavos e guarda a taxa do PayPal" do
    expect(described_class.call(capture)).to eq(
      payment_fee_cents: 88, net_amount_cents: 1402, paypal_exchange_rate: 4.89294565.to_d,
      paypal_receivable_cents: 6860, paypal_receivable_currency: "BRL"
    )
  end

  it "devolve só as chaves presentes quando a conta recebe na moeda da venda" do
    capture["seller_receivable_breakdown"].delete("exchange_rate")
    capture["seller_receivable_breakdown"]["receivable_amount"] = { "value" => "14.02", "currency_code" => "USD" }

    expect(described_class.call(capture)).to eq(
      payment_fee_cents: 88, net_amount_cents: 1402, paypal_receivable_cents: 1402, paypal_receivable_currency: "USD"
    )
  end

  it "devolve vazio sem o breakdown (capture PENDING) e sem capture" do
    expect(described_class.call({ "id" => "CAP-1", "status" => "PENDING" })).to eq({})
    expect(described_class.call(nil)).to eq({})
  end
end
