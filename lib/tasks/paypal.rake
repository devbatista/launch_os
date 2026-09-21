namespace :paypal do
  desc "Lista os webhooks do app PayPal (ambiente de PAYPAL_ENV)"
  task webhooks: :environment do
    Providers::Paypal::Client.new.list_webhooks.each do |wh|
      puts "#{wh["id"]}  #{wh["url"]}  (#{wh["event_types"].size} eventos)"
    end
  end

  desc "Cria um webhook para HOST com os eventos tratados e imprime o id para PAYPAL_WEBHOOK_ID"
  task :webhook_create, [ :url ] => :environment do |_t, args|
    abort "uso: bin/rails paypal:webhook_create[https://host]" if args[:url].blank?

    url = "#{args[:url].chomp("/")}/webhooks/paypal"
    result = Providers::Paypal::Client.new.create_webhook(url)
    puts "webhook #{result["id"]} → #{result["url"]} (#{result["event_types"].size} eventos)"
    puts "Defina PAYPAL_WEBHOOK_ID=#{result["id"]} no ambiente que responde nessa URL."
  end

  desc "Aponta o webhook PAYPAL_WEBHOOK_ID para URL (dev: bin/tunnel faz isso após subir o túnel)"
  task :webhook_url, [ :url ] => :environment do |_t, args|
    abort "uso: bin/rails paypal:webhook_url[https://host]" if args[:url].blank?

    url = "#{args[:url].chomp("/")}/webhooks/paypal"
    result = Providers::Paypal::Client.new.update_webhook_url(url)
    puts "webhook #{result["id"]} → #{result["url"]}"
  end
end
