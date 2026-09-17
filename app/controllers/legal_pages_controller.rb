# Páginas legais públicas (docs/specs/14-paginas-legais.md): texto versionado em app/views/legal_pages,
# em inglês americano, com a data de atualização visível. Cacheáveis; não dependem de sessão.
class LegalPagesController < ApplicationController
  allow_unauthenticated_access
  layout "landing"

  # Atualize ao mudar o texto da página correspondente.
  LAST_UPDATED = {
    privacy: Date.new(2026, 9, 17),
    terms: Date.new(2026, 9, 17),
    refund: Date.new(2026, 9, 17)
  }.freeze

  DEFAULT_REFUND_DAYS = 14

  before_action { expires_in 1.hour, public: true }

  def privacy
    @last_updated = LAST_UPDATED[:privacy]
  end

  def terms
    @last_updated = LAST_UPDATED[:terms]
  end

  # Com `?product=<slug>` (link do rodapé da LP) o prazo é o do produto; senão, o padrão.
  def refund
    @last_updated = LAST_UPDATED[:refund]
    @product = Product.find_by(slug: params[:product]) if params[:product].present?
    @refund_days = @product&.refund_days || DEFAULT_REFUND_DAYS
  end
end
