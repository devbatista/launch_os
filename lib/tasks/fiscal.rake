namespace :fiscal do
  desc "CSV das vendas do mês para a contabilidade: fiscal:export[2026,10] (opcional: caminho de saída)"
  task :export, %i[year month path] => :environment do |_t, args|
    abort "uso: bin/rails 'fiscal:export[2026,10]'" if args[:year].blank? || args[:month].blank?

    export = Fiscal::Export.new(year: args[:year], month: args[:month])
    csv = export.call

    if args[:path].present?
      File.write(args[:path], csv)
      warn "#{export.orders.size} pedido(s) → #{args[:path]}"
    else
      puts csv
    end
  end

  desc "Preenche tarifa/líquido/câmbio dos pedidos antigos a partir dos webhooks já guardados"
  task backfill_paypal: :environment do
    scope = Order.where(payment_fee_cents: nil).where.not(paid_at: nil)
    total = scope.count
    with_breakdown = country_only = 0

    scope.to_a.each do |order|
      event = order.webhook_events.where(event_type: "PAYMENT.CAPTURE.COMPLETED").order(:created_at).last
      attrs = Providers::Paypal::Breakdown.call(event&.payload&.dig("resource"))
      breakdown = attrs.any?
      attrs[:payer_country] = order.client&.country if order.payer_country.blank?
      attrs = attrs.compact
      next if attrs.empty?

      order.update_columns(**attrs, updated_at: Time.current) # sem callbacks: é correção de dado histórico
      breakdown ? with_breakdown += 1 : country_only += 1
    end

    puts "#{total} pedido(s) sem tarifa: #{with_breakdown} com breakdown da captura, #{country_only} só com país"
    puts "Sem breakdown = pedido sem PAYMENT.CAPTURE.COMPLETED guardado (capture pelo front, sem webhook)." if total > with_breakdown
  end
end
