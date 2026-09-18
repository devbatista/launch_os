# GET /download/:token (spec 08): conta o download sob lock e redireciona para a URL assinada do PDF
# (5 minutos, bucket privado). Nunca serve o arquivo pelo Rails. Token inativo → página de erro
# com o motivo: 410 (expirado/revogado), 429 (limite), 402 (pagamento não confirmado).
class DownloadsController < ApplicationController
  include ActiveStorage::SetCurrent # o serviço Disk (test/local) precisa de url_options para assinar a URL

  allow_unauthenticated_access
  layout "landing"
  rate_limit to: 30, within: 10.minutes, with: -> { render plain: "Too many requests. Please try again in a few minutes.", status: :too_many_requests }

  SIGNED_URL_TTL = 5.minutes
  STATUS_BY_REASON = { expired: :gone, revoked: :gone, limit_reached: :too_many_requests, not_paid: :payment_required }.freeze

  def show
    @token = DownloadToken.includes(order: :product).find_by!(token: params[:token])
    @order = @token.order
    response.cache_control.replace(no_store: true)

    unless @token.active?
      @reason = @token.inactive_reason
      return render :unavailable, status: STATUS_BY_REASON.fetch(@reason)
    end

    @token.register_download!
    Rails.logger.info { "[downloads] order=#{@order.id} count=#{@token.download_count}/#{@token.max_downloads}" }

    pdf = @order.product.pdf_file
    redirect_to pdf.url(expires_in: SIGNED_URL_TTL, disposition: "attachment", filename: "#{@order.product.slug}.pdf"),
                allow_other_host: true, status: :see_other
  rescue ActiveRecord::RecordInvalid
    # Perdeu a corrida para o último download permitido.
    @reason = :limit_reached
    render :unavailable, status: :too_many_requests
  end
end
