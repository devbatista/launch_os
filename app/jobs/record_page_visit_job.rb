# Grava uma PageVisit fora do request (spec 10). Recebe só dados já saneados pelo VisitsController
# (ip_hash pronto, sem IP cru). Bots são ignorados aqui também (defesa em profundidade).
class RecordPageVisitJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordInvalid

  def perform(attrs)
    attrs = attrs.to_h.symbolize_keys
    return if PageVisit.bot?(attrs[:user_agent])

    PageVisit.create!(attrs.slice(:product_id, :path, :referrer, :user_agent, :ip_hash, :visitor_id, *PageVisit::ATTRIBUTION_FIELDS.map(&:to_sym)))
  end
end
