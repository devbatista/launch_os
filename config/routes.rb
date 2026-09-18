require "sidekiq/web"

Rails.application.routes.draw do
  # Tabela completa em docs/specs/12-rotas.md. Rotas fixas primeiro; `GET /:slug` sempre por último.

  # Health check usado pelo Railway e pelo monitor de uptime.
  get "up" => "rails/health#show", as: :rails_health_check

  # Painel do Sidekiq só com sessão de admin válida (mesmo cookie do painel); sem sessão a rota não
  # existe (404), para não revelar o painel.
  admin_authenticated = ->(request) { request.cookie_jar.signed[:session_id].then { |id| id.present? && Session.exists?(id:) } }
  constraints admin_authenticated do
    mount Sidekiq::Web => "/admin/sidekiq"
  end

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

    # Pedidos, clientes e auditoria de webhooks (spec 11). Nenhuma ação altera valor ou marca como pago.
    resources :orders, only: %i[index show] do
      member do
        post :resend           # channel=email|whatsapp
        post :regenerate_token
        post :revoke_token
        post :resolve_dispute  # outcome=paid|refunded
      end
    end
    resources :clients, only: %i[index show] do
      member { post :revoke_whatsapp_opt_in }
    end
    resources :webhook_events, only: %i[index show]
  end

  # Checkout (spec 07): chamado por modules/checkout.js; null_session, rate limit por IP.
  namespace :checkout do
    post "paypal",         to: "paypal#create"
    post "paypal/capture", to: "paypal#capture"
  end

  # Webhooks (spec 07/09): sem sessão nem CSRF; assinatura verificada no controller.
  namespace :webhooks do
    post "paypal", to: "paypal#create"
  end

  # Entrega (spec 08): a Thank You é por id do pedido e NÃO libera o arquivo — o link de download
  # (por token) vai só por email/WhatsApp (decisão 18/09). /access/recover reenvia o link por email.
  get "thank-you/:id",   to: "thank_you#show", as: :thank_you
  get "download/:token", to: "downloads#show", as: :download
  get  "access/recover", to: "access_recoveries#new", as: :access_recover
  post "access/recover", to: "access_recoveries#create"

  # Páginas legais (spec 14). `?product=<slug>` na refund policy mostra o prazo daquele produto.
  get "privacy",       to: "legal_pages#privacy", as: :privacy
  get "terms",         to: "legal_pages#terms",   as: :terms
  get "refund-policy", to: "legal_pages#refund",  as: :refund_policy

  # LP pública. Sempre a ÚLTIMA rota: captura qualquer /:slug que não bateu nas rotas fixas acima
  # (slugs reservados são rejeitados no modelo — Product::RESERVED_SLUGS).
  get "/:slug", to: "landing_pages#show", as: :landing_page, constraints: { slug: /[a-z0-9-]+/ }
end
