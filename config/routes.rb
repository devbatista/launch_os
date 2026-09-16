Rails.application.routes.draw do
  # Tabela completa em docs/specs/12-rotas.md. Rotas fixas primeiro; `GET /:slug` sempre por último.

  # Health check usado pelo Railway e pelo monitor de uptime.
  get "up" => "rails/health#show", as: :rails_health_check

  # Caixa de saída de emails em desenvolvimento.
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
