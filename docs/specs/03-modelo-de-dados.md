# 03 — Modelo de dados

Duas entidades de pessoas separadas de propósito: **`User`** opera o admin; **`Client`** compra.
Comprador nunca tem senha (acesso por token). `User` não se relaciona com `Client` nem `Order`.

Convenções:
- **Chaves primárias `id uuid`** em todas as tabelas (inclusive Active Storage, Action Text e `sessions`),
  geradas pelo Postgres com `gen_random_uuid()` (nativo desde o Postgres 13; não precisa da extensão `pgcrypto`).
  Toda FK é `type: :uuid`. Ver seção "UUID como chave primária".
- Timestamps `created_at`/`updated_at` em todas as tabelas.
- Dinheiro em `*_cents integer` + `currency string(3)`.
- Enums de status como `string` com `enum` do Rails (legível no banco e no admin).
- Emails normalizados em minúsculas e sem espaços antes de salvar.

## UUID como chave primária

Motivos: ids não sequenciais nas URLs do admin e nos identificadores enviados a terceiros
(`custom_id` do PayPal, `PayPal-Request-Id`), sem revelar volume de pedidos; facilita futuras
integrações/migrações entre ambientes.

Configuração obrigatória **antes da primeira migration**:

```ruby
# config/initializers/generators.rb
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

Com isso, `rails g model`, `rails g authentication`, `rails active_storage:install` e
`rails action_text:install` geram tabelas com `id: :uuid` e FKs `type: :uuid`
(`active_storage_attachments.record_id` incluído — por isso o initializer vem antes de tudo).

```ruby
# exemplo de migration
create_table :orders, id: :uuid do |t|
  t.references :client,  type: :uuid, foreign_key: true, null: true
  t.references :product, type: :uuid, foreign_key: true, null: false
  ...
end
```

Consequências a respeitar no código:
- **Não há ordem implícita por `id`.** `Model.first`/`.last` e `order(:id)` deixam de significar cronologia.
  Definir em `ApplicationRecord`: `self.implicit_order_column = "created_at"` e sempre usar
  `order(created_at: :desc)` explicitamente em listagens.
- `created_at` DEVE ter índice nas tabelas listadas/filtradas por data (`orders`, `page_visits`, `message_logs`, `webhook_events`).
- Ids em URLs do admin ficam longos (`/admin/orders/9b2f…`); aceitável. `Product` continua usando `slug` em `to_param`.
- `Order#id` vai para o PayPal em `reference_id` e `custom_id` (36 chars, dentro do limite de 127) e como
  `PayPal-Request-Id`. O webhook localiza o pedido por esse UUID.
- Factories não devem depender de ids sequenciais; use `create(:order)` e compare por objeto.
- `schema.rb` registra `enable_extension "pgcrypto"`? **Não** — Rails 7.1+ no Postgres 13+ usa `gen_random_uuid()` sem extensão. Se aparecer, remover.

## Diagrama

```
User (admin)          Session ──▶ User

Client ──< Order >── Product ──< Benefit
   │         │                ──< Testimonial
   │         │                ──< Faq
   │         ├── DownloadToken (has_one)
   │         └──< MessageLog
   └──────────< MessageLog

WebhookEvent (independente; referencia Order opcionalmente)
PageVisit ──▶ Product (opcional)
```

## Tabelas

### users

| Coluna | Tipo | Regras |
|---|---|---|
| name | string | obrigatório |
| email_address | string | único (índice, citext ou lower), obrigatório |
| password_digest | string | `has_secure_password` |
| role | string | default `"admin"` |
| last_sign_in_at | datetime | |
| failed_attempts | integer | default 0, not null |
| locked_at | datetime | null = desbloqueado |

Coluna `email_address` segue o gerador `rails g authentication`.

### sessions

| Coluna | Tipo |
|---|---|
| user_id | references uuid (fk) |
| ip_address | string |
| user_agent | string |

### clients

| Coluna | Tipo | Regras |
|---|---|---|
| name | string | |
| email | string | único (índice em `lower(email)`), obrigatório, formato válido |
| phone | string | E.164 (`+15551234567`), nulo se não informado |
| whatsapp_opt_in | boolean | default false, not null |
| whatsapp_opt_in_at | datetime | preenchido quando opt-in = true |
| whatsapp_opt_in_text | string | texto exato aceito (evidência TCPA) |
| whatsapp_opt_out_at | datetime | STOP ou pedido ao suporte |
| country | string(2) | do PayPal (`payer.address.country_code`) |
| first_purchase_at | datetime | |
| last_purchase_at | datetime | |

### products

| Coluna | Tipo | Regras |
|---|---|---|
| name | string | obrigatório |
| slug | string | único, obrigatório, `[a-z0-9-]+`, gerado de `name` se vazio |
| headline | string | obrigatório |
| subheadline | string | |
| description | text | rich text (Action Text) ou markdown — decisão: **Action Text** (já vem no Rails) |
| problem_text | text | bloco "problema/identificação" da LP |
| price_cents | integer | > 0, obrigatório |
| compare_at_price_cents | integer | nulo ou > price_cents |
| currency | string(3) | default `"USD"` |
| status | string | `draft` / `published` / `archived`, default `draft` |
| template | string | default `"direct_response"` |
| meta_title | string | |
| meta_description | string | |
| guarantee_text | text | |
| refund_days | integer | default 14 |
| published_at | datetime | |
| cta_text | string | default `"Buy Now"` |

Anexos (Active Storage): `pdf_file` (has_one), `cover_image` (has_one), `mockup_image` (has_one),
`og_image` (has_one), `preview_images` (has_many). Validações de content type e tamanho
(PDF ≤ 50 MB; imagens JPEG/PNG/WebP ≤ 5 MB).

Índices: `slug` único; `status`.

### benefits / testimonials / faqs

| Tabela | Colunas |
|---|---|
| benefits | product_id (fk), title (string, obrig.), description (text), position (integer) |
| testimonials | product_id (fk), author_name (string, obrig.), quote (text, obrig.), author_role (string), position (integer) |
| faqs | product_id (fk), question (string, obrig.), answer (text, obrig.), position (integer) |

Índice composto `(product_id, position)` em cada uma.

### orders

| Coluna | Tipo | Regras |
|---|---|---|
| client_id | references uuid (fk) | nulo até o capture retornar o email do pagador |
| product_id | references uuid (fk) | obrigatório |
| status | string | `pending` / `paid` / `failed` / `refunded` / `disputed`, default `pending` |
| amount_cents | integer | copiado de `product.price_cents` na criação |
| currency | string(3) | copiado do produto |
| paypal_order_id | string | único (índice) |
| paypal_capture_id | string | único (índice), nulo até captura |
| payer_email | string | email retornado pelo PayPal |
| payer_name | string | |
| phone | string | E.164 informado no checkout |
| whatsapp_opt_in | boolean | default false (snapshot do checkout) |
| utm_source, utm_medium, utm_campaign, utm_content, utm_term | string | |
| fbclid | string | |
| fbp, fbc | string | cookies do Pixel (para CAPI futura) |
| landing_path | string | path da LP na primeira visita |
| referrer | string | |
| user_agent | string | |
| ip_address | string | |
| event_id | string | UUID para deduplicação Pixel/CAPI, gerado na criação |
| paid_at | datetime | |
| failed_at | datetime | |
| refunded_at | datetime | |
| disputed_at | datetime | |
| purchase_tracked_at | datetime | quando o Purchase foi disparado ao Pixel/GA4 |

Índices: `paypal_order_id` único, `paypal_capture_id` único, `status`, `client_id`, `product_id`, `created_at`.

### download_tokens

| Coluna | Tipo | Regras |
|---|---|---|
| order_id | references uuid (fk) | único (`has_one`) |
| token | string | único (índice), `SecureRandom.urlsafe_base64(32)` |
| expires_at | datetime | obrigatório |
| download_count | integer | default 0 |
| max_downloads | integer | default `ENV["DOWNLOAD_MAX_COUNT"]` (10) |
| revoked_at | datetime | |
| last_downloaded_at | datetime | |

### webhook_events

| Coluna | Tipo | Regras |
|---|---|---|
| provider | string | `paypal` / `twilio` |
| external_id | string | id do evento no provedor |
| event_type | string | ex.: `PAYMENT.CAPTURE.COMPLETED` |
| payload | jsonb | corpo bruto |
| headers | jsonb | cabeçalhos relevantes (assinatura) |
| signature_valid | boolean | |
| status | string | `received` / `processed` / `ignored` / `failed` |
| error | text | |
| processed_at | datetime | |
| order_id | references uuid | opcional, preenchido após correlação |

Índices: **único** em `(provider, external_id)` — é a chave de idempotência; `status`; `created_at`.

### message_logs

| Coluna | Tipo | Regras |
|---|---|---|
| client_id | references uuid (fk) | |
| order_id | references uuid (fk) | |
| channel | string | `email` / `whatsapp` |
| template | string | `order_delivery` / `access_resend` / `refund_confirmation` |
| recipient | string | email ou telefone |
| provider_message_id | string | Message-ID ou Twilio SID (índice) |
| status | string | `queued` / `sent` / `delivered` / `read` / `failed` / `undelivered` |
| error_code | string | |
| error_message | text | |
| sent_at, delivered_at, read_at, failed_at | datetime | |
| attempts | integer | default 0 |

Índices: `provider_message_id`; `(order_id, created_at)`; `status`.

### page_visits (opcional no MVP, recomendado)

| Coluna | Tipo |
|---|---|
| product_id | references uuid |
| path | string |
| utm_source, utm_medium, utm_campaign, utm_content, utm_term, fbclid | string |
| referrer | string |
| user_agent | string |
| ip_hash | string (SHA256 do IP + salt diário; não armazenar IP cru) |
| visitor_id | string (cookie first-party) |

Gravado por job assíncrono para não pesar a LP. Índice em `(product_id, created_at)`.

## Modelos (esboço)

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  self.implicit_order_column = "created_at"   # UUIDs não são cronológicos
end

class Product < ApplicationRecord
  has_many :benefits, -> { order(:position) }, dependent: :destroy
  has_many :testimonials, -> { order(:position) }, dependent: :destroy
  has_many :faqs, -> { order(:position) }, dependent: :destroy
  has_many :orders
  has_one_attached :pdf_file
  has_one_attached :cover_image
  has_one_attached :mockup_image
  has_one_attached :og_image
  has_many_attached :preview_images
  has_rich_text :description

  enum :status, { draft: "draft", published: "published", archived: "archived" }, default: :draft

  validates :name, :headline, :slug, :price_cents, :currency, presence: true
  validates :slug, uniqueness: true, format: /\A[a-z0-9-]+\z/
  validates :price_cents, numericality: { greater_than: 0 }
  validate  :compare_at_price_greater_than_price
  validate  :pdf_present_when_published

  def price = Money.new(price_cents, currency) # ou helper próprio; não precisa da gem money
  def to_param = slug
end

class Client < ApplicationRecord
  has_many :orders
  has_many :message_logs
  normalizes :email, with: ->(e) { e.strip.downcase }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: URI::MailTo::EMAIL_REGEXP
  validates :phone, phone: { allow_blank: true }  # phonelib

  def whatsapp_deliverable? = whatsapp_opt_in? && phone.present? && whatsapp_opt_out_at.nil?
end

class Order < ApplicationRecord
  belongs_to :client, optional: true
  belongs_to :product
  has_one :download_token, dependent: :destroy
  has_many :message_logs
  has_many :webhook_events

  enum :status, { pending: "pending", paid: "paid", failed: "failed",
                  refunded: "refunded", disputed: "disputed" }, default: :pending

  before_create { self.event_id ||= SecureRandom.uuid }
end

class DownloadToken < ApplicationRecord
  belongs_to :order
  has_secure_token :token, length: 36   # Rails gera token urlsafe; índice único

  def active?  = revoked_at.nil? && expires_at.future? && download_count < max_downloads && order.paid?
  def revoke!  = update!(revoked_at: Time.current)
end
```

## Migrations (ordem)

0. `config/initializers/generators.rb` com `primary_key_type: :uuid` — **antes de qualquer generator**.
1. `create_users` + `create_sessions` (gerador de autenticação) + colunas de lockout.
2. `create_products` (+ Action Text, Active Storage tables — conferir `id: :uuid` e `record_id` uuid).
3. `create_benefits`, `create_testimonials`, `create_faqs`.
4. `create_clients`.
5. `create_orders`.
6. `create_download_tokens`.
7. `create_webhook_events`.
8. `create_message_logs`.
9. `create_page_visits`.

Não há tabelas de jobs no Postgres: o Sidekiq usa o Redis (projeto gerado com `--skip-solid`).

Todas as tabelas com `id: :uuid`; todas as FKs com `type: :uuid, foreign_key: true`; `null: false` onde a coluna é obrigatória.

## Seeds

`db/seeds.rb` DEVE criar:
- `User` admin a partir de `ADMIN_EMAIL` / `ADMIN_PASSWORD` (env), sem sobrescrever se já existir.
- Em development: um `Product` de exemplo em `draft` com benefícios, FAQ e imagens placeholder
  (para desenvolver a LP sem cadastro manual). O PDF real do 21-Day Procrastination Reset é
  cadastrado manualmente via admin, não via seed.

## Critérios de aceite

- [ ] `bin/rails db:migrate` e `db:schema:load` funcionam em banco limpo.
- [ ] Factories (`spec/factories/`) com traits para cada status de `Product`, `Order` e `DownloadToken`.
- [ ] Model specs cobrem: unicidade de slug, email normalizado, `compare_at_price > price`,
      produto publicado exige PDF, `DownloadToken#active?` em cada condição.
- [ ] Índice único `(provider, external_id)` em `webhook_events` existe.
- [ ] Nenhuma coluna monetária em float/decimal.
- [ ] `db/schema.rb`: toda `create_table` tem `id: :uuid` (inclusive `active_storage_*`, `action_text_rich_texts`, `sessions`) e toda coluna `*_id` é `uuid`; `grep -c "id: :uuid" db/schema.rb` = número de tabelas.
- [ ] `ApplicationRecord.implicit_order_column == "created_at"`; nenhum `order(:id)` no código.
