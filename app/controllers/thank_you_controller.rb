# Página pós-compra (spec 08, decisão 18/09): identificada pelo id do pedido e sem link de download —
# o link (por token) chega só por email/WhatsApp, então a URL desta página não dá acesso ao arquivo.
# Estados: pagamento pendente, pago (confirmação + para onde o link foi) e inativo. Nunca cacheada.
# Na primeira visita de um pedido pago marca `purchase_tracked_at` (Purchase disparado uma vez — spec 10).
class ThankYouController < ApplicationController
  allow_unauthenticated_access
  layout "landing"

  def show
    @order = Order.includes(:product, :client).find(params[:id])
    @product = @order.product
    @track_purchase = track_purchase_once!
    response.cache_control.replace(no_store: true)
  end

  private
    def track_purchase_once!
      return false unless @order.paid? && @order.purchase_tracked_at.nil?

      @order.update_column(:purchase_tracked_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
      true
    end
end
