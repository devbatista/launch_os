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
      end

      # Coleções da LP: respondem com o partial da lista (fetch) ou redirect (sem JS).
      resources :benefits, :testimonials, :faqs, only: %i[create update destroy] do
        member { patch :move }
      end
    end
  end
end
