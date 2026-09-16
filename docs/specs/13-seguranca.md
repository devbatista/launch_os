# 13 — Segurança

Checklist obrigatório. Nenhum item é opcional para ir ao ar.

## Transporte e segredos

- [ ] HTTPS em todas as páginas (`force_ssl`, HSTS).
- [ ] Segredos (PayPal, Twilio, SES, S3, Sentry, master key) somente em ENV / credentials; `.env` gitignored.
- [ ] Usuário IAM do SES restrito a `ses:SendEmail`/`ses:SendRawEmail` com o `From` fixo; usuário IAM do S3 restrito ao bucket. Nunca credenciais root.
- [ ] Nenhuma chamada a API externa fora de `app/services/providers/` (`grep -rn "Faraday\|Aws::SESV2\|api.twilio.com\|paypal.com" app | grep -v app/services/providers` retorna vazio).
- [ ] Assinatura da Twilio validada com `secure_compare` (sem comparação `==`).
- [ ] `/letter_opener` montado apenas em `development` (gem no grupo `:development`).
- [ ] `PAYPAL_WEBHOOK_SKIP_VERIFY` e similares levantam exceção no boot se definidos em `production`.
- [ ] Nunca logar payloads com telefone/email em texto plano em logs públicos; filtrar via
      `config.filter_parameters += [:phone, :email, :password, :payer_email]`.

## Pagamento

- [ ] Preço sempre do `Product` no backend; parâmetro de valor do cliente é ignorado.
- [ ] Assinatura de todo webhook (PayPal e Twilio) verificada antes de qualquer processamento.
- [ ] Idempotência: índice único `(provider, external_id)` em `webhook_events`; `Orders::MarkPaid` no-op se já pago; `PayPal-Request-Id` no create/capture.
- [ ] Nenhum dado de cartão trafega ou é armazenado; pagamento 100% no PayPal.
- [ ] Transições de estado do `Order` apenas via services, dentro de `with_lock`.

## Entrega

- [ ] Bucket privado; PDF servido só por URL assinada (≤ 5 min); acesso direto ao objeto → 403.
- [ ] Token longo e aleatório (`has_secure_token`, ≥ 32 bytes); comparação por lookup indexado.
- [ ] Token verifica `order.paid?` a cada uso (refund/disputa revogam).
- [ ] Expiração e limite de downloads aplicados.
- [ ] Recuperação de acesso com resposta uniforme (não enumera emails) + rate limit + honeypot.

## Admin

- [ ] `has_secure_password` (bcrypt), senha ≥ 12 chars, lockout após 5 falhas, rate limit no login.
- [ ] Todas as rotas `/admin/*` atrás de `require_authentication`.
- [ ] CSRF habilitado em todos os controllers com sessão (`protect_from_forgery`); webhooks em `ActionController::API`.
- [ ] Strong parameters em todos os formulários; nada de `permit!`.
- [ ] Dados de `Client` (email, telefone) visíveis só a `User` autenticado; telefone mascarado nas listagens.
- [ ] Uploads validados (content type via magic bytes do Active Storage, tamanho, quantidade).

## Aplicação

- [ ] `Content-Security-Policy` configurada: `default-src 'self'`; `script-src` com `'self'`, `www.paypal.com`,
      `connect.facebook.net`, `www.googletagmanager.com`; `connect-src` com PayPal/Meta/GA; `img-src` com bucket,
      `www.facebook.com`; `frame-src` `www.paypal.com`. Nonces para scripts inline (`content_security_policy_nonce_generator`).
- [ ] Headers: `X-Content-Type-Options`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` mínimo.
- [ ] Rate limiting nativo (`rate_limit`) nos endpoints listados em [12-rotas.md](12-rotas.md).
- [ ] `config.hosts` com `www.devbatista.online`, `devbatista.online` e `*.up.railway.app` em produção.
- [ ] Sem `raise` silencioso em jobs: erros vão ao Sentry; retentativas limitadas.
- [ ] `brakeman` sem alertas de confiança alta; `bundle audit` limpo; Dependabot habilitado.
- [ ] Logs de webhook, downloads, mensagens e falhas de login retidos ≥ 90 dias (Postgres) — payloads
      de webhook PODEM ser expurgados após 90 dias por recurring task.

## Dados pessoais

- [ ] Telefone armazenado apenas com opt-in; texto e data/hora do consentimento gravados (TCPA).
- [ ] STOP respeitado imediatamente.
- [ ] `PageVisit` guarda hash do IP, não o IP; `Order` guarda IP (necessário para CAPI e antifraude) — mencionado na Privacy Policy.
- [ ] Privacy Policy, Terms e Refund Policy publicados e coerentes com a operação real (ver [14](14-paginas-legais.md)).
- [ ] Backup do banco criptografado em repouso (recurso da plataforma).

## Critérios de aceite

- [ ] Checklist acima 100% marcado e revisado por segunda pessoa antes da campanha.
- [ ] Teste manual: adulterar valor no `POST /checkout/paypal` via DevTools → PayPal ainda cobra US$ 14.90.
- [ ] Teste manual: `curl -X POST /webhooks/paypal` com corpo forjado → 400, nada processado.
- [ ] Teste manual: URL do bucket sem assinatura → 403.
