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
  end
end
