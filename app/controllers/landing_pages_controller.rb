# LP pública de um produto (docs/specs/06-landing-page.md). Só `published` responde; draft/archived → 404.
# A página é cacheável (ETag por `updated_at` — coleções e anexos dão `touch` no produto) e não depende
# de sessão. Atribuição (spec 10) e preview (1.7) entram nas próprias tarefas.
class LandingPagesController < ApplicationController
  allow_unauthenticated_access
  layout "landing"

  def show
    @product = Product.published.find_by!(slug: params[:slug])

    expires_in 60.seconds, public: true
    return unless stale?(@product, public: true)

    render "landing_pages/templates/#{@product.template}/show"
  end
end
