namespace :ads do
  desc "JSON da campanha de um produto para a skill analisar-campanha: ads:snapshot[slug] (opcional: since,until em ISO8601)"
  task :snapshot, %i[slug since until] => :environment do |_t, args|
    abort "uso: bin/rails 'ads:snapshot[21-day-procrastination-reset]' ou 'ads:snapshot[slug,2026-10-02,2026-10-09]'" if args[:slug].blank?

    product = Product.find_by!(slug: args[:slug])
    snapshot = MetaAds::CampaignSnapshot.call(product, since: args[:since].presence && Date.iso8601(args[:since]),
                                                       until_date: args[:until].presence && Date.iso8601(args[:until]))
    puts snapshot.to_json # uma linha só: o log do Rails também vai para o STDOUT
  end

  desc "Puxa agora o Insights da Meta (mesma janela do cron): ads:sync (opcional: since,until em ISO8601)"
  task :sync, %i[since until] => :environment do |_t, args|
    abort "Meta Ads desligado: falta META_ACCESS_TOKEN ou META_AD_ACCOUNT_ID" unless MetaAds.insights_enabled?

    rows = MetaAds::SyncInsights.call(since: args[:since].presence && Date.iso8601(args[:since]),
                                      until_date: args[:until].presence && Date.iso8601(args[:until]))
    puts "#{rows} linha(s) de insights gravada(s)"
  end
end
