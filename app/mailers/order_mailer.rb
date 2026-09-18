# Emails ao comprador (spec 09), HTML + texto. `delivery` e `access_resend` levam o link de download
# por token — o único caminho até o arquivo (decisão 18/09 na spec 08); `refund_confirmation` avisa que
# o acesso foi encerrado. O PDF nunca vai anexado.
class OrderMailer < ApplicationMailer
  helper :application

  before_action :load_order

  def delivery
    mail(to: recipient, subject: "Your download is ready — #{@product.name}")
  end

  def access_resend
    mail(to: recipient, subject: "Here's your download link — #{@product.name}")
  end

  def refund_confirmation
    mail(to: recipient, subject: "Your refund for #{@product.name} has been processed")
  end

  private
    def load_order
      @order = params.fetch(:order)
      @product = @order.product
      @client = @order.client
      @first_name = @client&.name.to_s.split.first.presence
      @token = @order.download_token
      @download_url = @token && download_url(@token.token)
      @recover_url = ActionDispatch::Http::URL.full_url_for(default_url_options.merge(path: "/access/recover"))
    end

    # Nome do comprador no cabeçalho quando conhecido: "Jane Buyer <jane@…>".
    def recipient
      email = @client&.email || @order.payer_email
      raise ArgumentError, "order #{@order.id} has no recipient email" if email.blank?

      name = @client&.name.presence
      name ? Mail::Address.new(email).tap { |a| a.display_name = name }.format : email
    end
end
