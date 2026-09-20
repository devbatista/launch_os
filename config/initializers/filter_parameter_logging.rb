# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
# `email` cobre `payer_email`; `phone` cobre o telefone do checkout e do webhook da Twilio (From/To
# viram `from`/`to`, filtrados por nome abaixo). Spec 13: nada de email/telefone em texto plano no log.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :phone, :from, :to, :body, :name
]
