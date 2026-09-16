# 04 — Autenticação do admin

Um único `User` no MVP. Sem cadastro público, sem OAuth, sem "esqueci minha senha" por email
(reset via `bin/rails runner` / console; o gerador cria `passwords_controller` — PODE manter).

## Base

`bin/rails generate authentication` (Rails 8) gera:
- `User` (`has_secure_password`, `email_address`), `Session`, `Current`.
- `Authentication` concern (`require_authentication`, `allow_unauthenticated_access`, `start_new_session_for`, `terminate_session`).
- `SessionsController` (`new`, `create`, `destroy`), `PasswordsController`.
- Cookie de sessão `signed`, `httponly`, `same_site: :lax`.

Adaptações:
- Mover rotas para o namespace `/admin` (`GET|POST /admin/login`, `DELETE /admin/logout`).
- `Admin::BaseController < ApplicationController` com `before_action :require_authentication`.
- Controllers públicos (LP, checkout, webhooks, download, legal) usam `allow_unauthenticated_access`.
- Webhooks: `skip_forgery_protection` (ver [07](07-checkout-paypal.md) e [09](09-notificacoes-email-whatsapp.md)).

## Regras de senha e bloqueio

| Regra | Valor |
|---|---|
| Comprimento mínimo | 12 caracteres |
| Hash | bcrypt (`has_secure_password`), cost padrão (12) |
| Tentativas falhas antes de bloquear | 5 |
| Duração do bloqueio | 15 minutos (`locked_at` + 15.min) |
| Rate limit do endpoint de login | 10 req / 3 min por IP (`rate_limit to: 10, within: 3.minutes, only: :create`) |
| Expiração de sessão | 2 semanas de inatividade (opcional) ou logout explícito |

Fluxo de `SessionsController#create`:

```
user = User.find_by(email_address: params[:email_address])
if user&.locked?          → flash "Try again later", registrar tentativa, redirect (sem revelar existência)
elsif user&.authenticate  → reset failed_attempts, locked_at = nil, last_sign_in_at = now, start_new_session_for
else                      → user&.register_failed_attempt! (incrementa; bloqueia ao atingir 5), flash genérico
```

A mensagem de erro é sempre a mesma ("Invalid email or password") para não expor se o email existe.

## Segurança adicional

- `Content-Security-Policy` habilitada para o admin (scripts apenas `self`).
- Cookie de sessão com `secure: true` em produção (automático com `force_ssl`).
- Log de `last_sign_in_at` e IP na `Session`.
- Registrar tentativas falhas em log (`Rails.logger.warn`) e enviar ao Sentry como breadcrumb.
- Nenhuma rota `/admin/*` acessível sem sessão → redirect para `/admin/login`.

## Criação do usuário

Via seed (`ADMIN_EMAIL` + `ADMIN_PASSWORD`) ou:

```bash
docker compose exec web bin/rails runner 'User.create!(name: "Dev", email_address: "x@y.com", password: ENV.fetch("PW"))'
```

Nunca senha hardcoded.

## Critérios de aceite

- [ ] Login com credenciais válidas cria `Session` e redireciona para `/admin/dashboard`.
- [ ] 5 senhas erradas seguidas bloqueiam por 15 min; a 6ª tentativa correta ainda falha durante o bloqueio.
- [ ] 11ª requisição de login em 3 min retorna 429.
- [ ] `GET /admin/products` sem sessão redireciona para `/admin/login`.
- [ ] Logout invalida a sessão (cookie não reutilizável).
- [ ] Senha com 11 caracteres é rejeitada na criação.
