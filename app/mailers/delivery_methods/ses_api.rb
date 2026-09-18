module DeliveryMethods
  # Delivery method `:ses_api` do Action Mailer (spec 09): o mailer renderiza normalmente (templates,
  # multipart, previews) e só a entrega passa pelo Providers::Ses::Client. Registrado em
  # config/initializers/action_mailer.rb e usado apenas em production; dev usa letter_opener_web, test :test.
  class SesApi
    def initialize(settings = {})
      @settings = settings
    end

    def deliver!(mail)
      message_id = client.send_raw_email(mail)
      mail.message_id = "<#{message_id}@email.amazonses.com>" # disponível em `mail.message_id` após deliver_now
      message_id
    end

    private
      def client = @client ||= @settings[:client] || Providers::Ses::Client.new
  end
end
