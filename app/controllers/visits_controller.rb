# POST /visits (spec 10): beacon enviado por modules/attribution.js ao carregar a LP. A LP é cacheada
# pelo Thruster, então é este endpoint (nunca cacheado) que conta visitas. Responde 204 sempre; o
# registro fica a cargo do RecordPageVisitJob. Sem sessão/CSRF (sendBeacon não manda token); rate limit
# por IP e payload restrito às chaves conhecidas, truncadas.
class VisitsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection
  rate_limit to: 60, within: 1.minute, with: -> { head :too_many_requests }

  MAX_LENGTH = 255

  def create
    return head :no_content if PageVisit.bot?(request.user_agent)

    product = Product.published.find_by(slug: params[:product].to_s)
    RecordPageVisitJob.perform_later(
      product_id: product&.id,
      path: clip(params[:path].presence || (product && "/#{product.slug}") || "/"),
      referrer: clip(params[:referrer]),
      user_agent: clip(request.user_agent),
      ip_hash: PageVisit.ip_hash(request.remote_ip),
      visitor_id: clip(cookies[:lo_vid].presence || params[:visitor_id]),
      **PageVisit::ATTRIBUTION_FIELDS.index_with { |k| clip(params[k]) }.except("referrer").symbolize_keys
    )
    head :no_content
  end

  private
    def clip(value) = value.presence && value.to_s.first(MAX_LENGTH)
end
