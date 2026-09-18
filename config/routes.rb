Rails.application.routes.draw do
  # Tabela completa em docs/specs/12-rotas.md. Rotas fixas primeiro; `GET /:slug` sempre por último.

  # Health check usado pelo Railway e pelo monitor de uptime.
  get "up" => "rails/health#show", as: :rails_health_check

  # Caixa de saída de emails em desenvolvimento.
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  namespace :admin do
    get    "login",  to: "sessions#new",     as: :login
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    root to: redirect("/admin/dashboard")
    resource :dashboard, only: :show

    # :id e :product_id são o slug do produto (Product#to_param).
    resources :products do
      member do
        patch :publish
        patch :unpublish
        patch :archive
        get :preview # LP em modo rascunho, qualquer status
      end

      # Remoção individual de arquivos (PDF, imagens, previews) — id = ActiveStorage::Attachment.
      resources :attachments, only: :destroy

      # Coleções da LP: respondem com o partial da lista (fetch) ou redirect (sem JS).
      resources :benefits, :testimonials, :faqs, only: %i[create update destroy] do
        member { patch :move }
      end
    end
  end

  # Checkout (spec 07): chamado por modules/checkout.js; null_session, rate limit por IP.
  namespace :checkout do
    post "paypal",         to: "paypal#create"
    post "paypal/capture", to: "paypal#capture"
  end

  # Páginas legais (spec 14). `?product=<slug>` na refund policy mostra o prazo daquele produto.
  get "privacy",       to: "legal_pages#privacy", as: :privacy
  get "terms",         to: "legal_pages#terms",   as: :terms
  get "refund-policy", to: "legal_pages#refund",  as: :refund_policy

  # LP pública. Sempre a ÚLTIMA rota: captura qualquer /:slug que não bateu nas rotas fixas acima
  # (slugs reservados são rejeitados no modelo — Product::RESERVED_SLUGS).
  get "/:slug", to: "landing_pages#show", as: :landing_page, constraints: { slug: /[a-z0-9-]+/ }
end
