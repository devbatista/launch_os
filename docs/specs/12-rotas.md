# 12 — Rotas

Ordem em `config/routes.rb`: rotas fixas primeiro; `GET /:slug` **por último**.

## Públicas

| Método | Rota | Controller#action | Auth | CSRF | Rate limit |
|---|---|---|---|---|---|
| GET | `/up` | `rails/health#show` | — | — | — |
| GET | `/` | `home#show` → redirect para o produto publicado mais recente ou 404 amigável | — | — | — |
| GET | `/:slug` | `landing_pages#show` | — | — | — |
| POST | `/checkout/paypal` | `checkout/paypal#create` | — | `null_session` (página cacheável; sem dependência de sessão) | 20/min/IP |
| POST | `/checkout/paypal/capture` | `checkout/paypal#capture` | — | `null_session` | 20/min/IP |
| GET | `/thank-you/:id` | `thank_you#show` (id do pedido; sem link de download — decisão 18/09) | — | — | — |
| GET | `/download/:token` | `downloads#show` | — | — | 30/10min/IP |
| GET | `/access/recover` | `access_recoveries#new` | — | — | — |
| POST | `/access/recover` | `access_recoveries#create` | — | token | 5/10min/IP |
| GET | `/privacy` | `legal_pages#privacy` | — | — | — |
| GET | `/terms` | `legal_pages#terms` | — | — | — |
| GET | `/refund-policy` | `legal_pages#refund` | — | — | — |

## Webhooks (`ActionController::API`, sem sessão, sem CSRF, assinatura obrigatória)

| Método | Rota | Controller#action | Validação |
|---|---|---|---|
| POST | `/webhooks/paypal` | `webhooks/paypal#create` | verify-webhook-signature (PayPal) |
| POST | `/webhooks/twilio/status` | `webhooks/twilio#status` | `X-Twilio-Signature` |
| POST | `/webhooks/twilio/inbound` | `webhooks/twilio#inbound` | `X-Twilio-Signature` |

## Admin (namespace `admin`, `Admin::BaseController` exige sessão)

| Método | Rota | Controller#action |
|---|---|---|
| GET | `/admin/login` | `admin/sessions#new` |
| POST | `/admin/login` | `admin/sessions#create` (rate limit 10/3min/IP) |
| DELETE | `/admin/logout` | `admin/sessions#destroy` |
| GET | `/admin` → redirect `/admin/dashboard` | |
| GET | `/admin/dashboard` | `admin/dashboards#show` |
| resources | `/admin/products` | `admin/products` (index, new, create, show, edit, update, destroy) |
| PATCH | `/admin/products/:id/publish` | `admin/products#publish` |
| PATCH | `/admin/products/:id/unpublish` | `admin/products#unpublish` |
| PATCH | `/admin/products/:id/archive` | `admin/products#archive` |
| GET | `/admin/products/:id/preview` | `admin/products#preview` |
| resources | `/admin/products/:product_id/benefits` | `admin/benefits` (create, update, destroy, move) |
| resources | `/admin/products/:product_id/testimonials` | `admin/testimonials` (idem) |
| resources | `/admin/products/:product_id/faqs` | `admin/faqs` (idem) |
| resources | `/admin/orders` | `admin/orders` (index, show) |
| POST | `/admin/orders/:id/resend` | `admin/orders#resend` (param `channel=email|whatsapp`) |
| POST | `/admin/orders/:id/regenerate_token` | `admin/orders#regenerate_token` |
| POST | `/admin/orders/:id/revoke_token` | `admin/orders#revoke_token` |
| POST | `/admin/orders/:id/resolve_dispute` | `admin/orders#resolve_dispute` (param `outcome=paid|refunded`) |
| resources | `/admin/clients` | `admin/clients` (index, show) |
| POST | `/admin/clients/:id/revoke_whatsapp_opt_in` | `admin/clients#revoke_whatsapp_opt_in` |
| GET | `/admin/webhook_events` | `admin/webhook_events` (index, show) — auditoria |
| mount | `/admin/sidekiq` | `Sidekiq::Web` — filas, retries, dead set; protegido por constraint de sessão |

## `routes.rb` (esboço)

```ruby
require "sidekiq/web"

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Painel do Sidekiq: só com sessão de User válida (mesmo cookie do admin)
  admin_authenticated = ->(request) {
    request.cookie_jar.signed[:session_id].then { |id| id && Session.exists?(id) }
  }
  constraints admin_authenticated do
    mount Sidekiq::Web => "/admin/sidekiq"
  end

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  namespace :admin do
    get  "login",  to: "sessions#new"
    post "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy"
    root to: redirect("/admin/dashboard")
    resource :dashboard, only: :show
    resources :products do
      member { patch :publish; patch :unpublish; patch :archive; get :preview }
      resources :benefits, :testimonials, :faqs, only: %i[create update destroy] do
        member { patch :move }
      end
    end
    resources :orders, only: %i[index show] do
      member { post :resend; post :regenerate_token; post :revoke_token; post :resolve_dispute }
    end
    resources :clients, only: %i[index show] do
      member { post :revoke_whatsapp_opt_in }
    end
    resources :webhook_events, only: %i[index show]
  end

  namespace :checkout do
    post "paypal",         to: "paypal#create"
    post "paypal/capture", to: "paypal#capture"
  end

  namespace :webhooks do
    post "paypal",         to: "paypal#create"
    post "twilio/status",  to: "twilio#status"
    post "twilio/inbound", to: "twilio#inbound"
  end

  get "thank-you/:id",    to: "thank_you#show",  as: :thank_you
  get "download/:token",  to: "downloads#show",  as: :download
  get  "access/recover",  to: "access_recoveries#new",    as: :access_recover
  post "access/recover",  to: "access_recoveries#create"
  get "privacy",       to: "legal_pages#privacy"
  get "terms",         to: "legal_pages#terms"
  get "refund-policy", to: "legal_pages#refund"

  root "home#show"
  get ":slug", to: "landing_pages#show", as: :landing_page, constraints: { slug: /[a-z0-9-]+/ }
end
```

## Critérios de aceite

- [ ] `bin/rails routes` corresponde à tabela.
- [ ] `/privacy`, `/terms`, `/thank-you/x` não são capturados por `landing_pages#show`.
- [ ] Todas as rotas `/admin/*` (exceto login) redirecionam sem sessão.
- [ ] Webhooks respondem sem cookie de sessão e sem token CSRF.
- [ ] `/admin/sidekiq` sem sessão → 404 (constraint não casa); com sessão → painel.
