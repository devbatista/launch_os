# Registra o delivery method `:ses_api` (DeliveryMethods::SesApi → Providers::Ses::Client), selecionado
# em config/environments/production.rb. `to_prepare` porque a classe é recarregável (app/): em dev ela é
# registrada de novo a cada reload. O client só é instanciado no primeiro envio, então dev/test nunca
# exigem credenciais do SES.
Rails.application.config.to_prepare do
  ActiveSupport.on_load(:action_mailer) { add_delivery_method :ses_api, DeliveryMethods::SesApi }
end
