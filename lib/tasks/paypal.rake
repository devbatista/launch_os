namespace :paypal do
  desc "Aponta o webhook PAYPAL_WEBHOOK_ID para URL (dev: bin/tunnel faz isso após subir o túnel)"
  task :webhook_url, [ :url ] => :environment do |_t, args|
    abort "uso: bin/rails paypal:webhook_url[https://host]" if args[:url].blank?

    url = "#{args[:url].chomp("/")}/webhooks/paypal"
    result = Providers::Paypal::Client.new.update_webhook_url(url)
    puts "webhook #{result["id"]} → #{result["url"]}"
  end
end
