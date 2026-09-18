# /rails/mailers/order_mailer — usa o último pedido pago do banco de dev (faça uma compra Sandbox antes).
class OrderMailerPreview < ActionMailer::Preview
  def delivery = OrderMailer.with(order:).delivery
  def access_resend = OrderMailer.with(order:).access_resend
  def refund_confirmation = OrderMailer.with(order:).refund_confirmation

  private
    def order
      order = Order.paid.includes(:client, :product, :download_token).order(paid_at: :desc).first
      raise "no paid order in this database — make a Sandbox purchase first" unless order

      order.download_token || order.create_download_token!
      order
    end
end
