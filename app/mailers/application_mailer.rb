# Remetente e Reply-To vêm do ambiente (spec 09): MAIL_FROM = "DevBatista <no-reply@devbatista.online>",
# respostas caem na caixa de suporte. Todo email ao comprador é em inglês americano.
class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "DevBatista <no-reply@devbatista.online>") },
          reply_to: -> { support_email }
  layout "mailer"

  helper_method :support_email

  private
    def support_email = ENV.fetch("SUPPORT_EMAIL", "support@devbatista.online")
end
