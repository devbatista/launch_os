# Avisos internos para a caixa de suporte (spec 09): o MVP não tem inbox de WhatsApp, então toda
# mensagem recebida é encaminhada por email ao operador (texto em pt-BR; a resposta ao comprador é
# feita à mão, em inglês). Sem o layout do comprador.
class SupportMailer < ApplicationMailer
  layout false

  def inbound_whatsapp
    @phone, @body, @client, @opted_out = params.values_at(:phone, :body, :client, :opted_out)
    who = @client&.name.presence || ApplicationController.helpers.masked_phone(@phone)
    mail(to: support_email, subject: @opted_out ? "[WhatsApp] STOP recebido de #{who}" : "[WhatsApp] Mensagem de #{who}")
  end
end
