# Helpers compartilhados entre admin e páginas públicas.
module ApplicationHelper
  # Dinheiro sempre a partir de centavos (nunca float), no formato americano ($14.90) independente
  # do locale — o produto é vendido em USD.
  def money(cents, currency = "USD")
    return "—" if cents.nil?
    number_to_currency(cents.to_d / 100, unit: currency == "USD" ? "$" : "#{currency} ", precision: 2,
                                         separator: ".", delimiter: ",", format: "%u%n")
  end
end
