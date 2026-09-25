# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_25_125157) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "benefits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.uuid "product_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "position"], name: "index_benefits_on_product_id_and_position"
  end

  create_table "clients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "country", limit: 2
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "first_purchase_at"
    t.datetime "last_purchase_at"
    t.string "name"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.boolean "whatsapp_opt_in", default: false, null: false
    t.datetime "whatsapp_opt_in_at"
    t.string "whatsapp_opt_in_text"
    t.datetime "whatsapp_opt_out_at"
    t.index "lower((email)::text)", name: "index_clients_on_lower_email", unique: true
  end

  create_table "download_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "download_count", default: 0, null: false
    t.datetime "expires_at", null: false
    t.datetime "last_downloaded_at"
    t.integer "max_downloads", default: 10, null: false
    t.uuid "order_id", null: false
    t.datetime "revoked_at"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_download_tokens_on_order_id", unique: true
    t.index ["token"], name: "index_download_tokens_on_token", unique: true
  end

  create_table "faqs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "answer", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.uuid "product_id", null: false
    t.string "question", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "position"], name: "index_faqs_on_product_id_and_position"
  end

  create_table "message_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.string "channel", null: false
    t.uuid "client_id"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "error_code"
    t.text "error_message"
    t.datetime "failed_at"
    t.uuid "order_id", null: false
    t.string "provider_message_id"
    t.datetime "read_at"
    t.string "recipient", null: false
    t.datetime "sent_at"
    t.string "status", default: "queued", null: false
    t.string "template", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_message_logs_on_client_id"
    t.index ["created_at"], name: "index_message_logs_on_created_at"
    t.index ["order_id", "created_at"], name: "index_message_logs_on_order_id_and_created_at"
    t.index ["provider_message_id"], name: "index_message_logs_on_provider_message_id"
    t.index ["status"], name: "index_message_logs_on_status"
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.uuid "client_id"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, null: false
    t.datetime "disputed_at"
    t.string "event_id", null: false
    t.datetime "failed_at"
    t.string "fbc"
    t.string "fbclid"
    t.string "fbp"
    t.string "ip_address"
    t.string "landing_path"
    t.integer "net_amount_cents"
    t.datetime "paid_at"
    t.string "payer_country", limit: 2
    t.string "payer_email"
    t.string "payer_name"
    t.integer "payment_fee_cents"
    t.string "paypal_capture_id"
    t.decimal "paypal_exchange_rate", precision: 18, scale: 8
    t.string "paypal_order_id"
    t.integer "paypal_receivable_cents"
    t.string "paypal_receivable_currency", limit: 3
    t.string "pending_reason"
    t.string "phone"
    t.uuid "product_id", null: false
    t.datetime "purchase_tracked_at"
    t.string "referrer"
    t.datetime "refunded_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.boolean "whatsapp_opt_in", default: false, null: false
    t.index ["client_id"], name: "index_orders_on_client_id"
    t.index ["created_at"], name: "index_orders_on_created_at"
    t.index ["paypal_capture_id"], name: "index_orders_on_paypal_capture_id", unique: true
    t.index ["paypal_order_id"], name: "index_orders_on_paypal_order_id", unique: true
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "page_visits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "fbclid"
    t.string "ip_hash"
    t.string "path", null: false
    t.uuid "product_id"
    t.string "referrer"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visitor_id"
    t.index ["created_at"], name: "index_page_visits_on_created_at"
    t.index ["product_id", "created_at"], name: "index_page_visits_on_product_id_and_created_at"
    t.index ["visitor_id"], name: "index_page_visits_on_visitor_id"
  end

  create_table "products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "compare_at_price_cents"
    t.datetime "created_at", null: false
    t.string "cta_text", default: "Buy Now", null: false
    t.string "currency", limit: 3, default: "USD", null: false
    t.text "guarantee_text"
    t.string "headline", null: false
    t.string "meta_description"
    t.string "meta_title"
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.text "problem_text"
    t.datetime "published_at"
    t.integer "refund_days", default: 14, null: false
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "subheadline"
    t.string "template", default: "direct_response", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_products_on_slug", unique: true
    t.index ["status"], name: "index_products_on_status"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "testimonials", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "author_name", null: false
    t.string "author_role"
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.uuid "product_id", null: false
    t.text "quote", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "position"], name: "index_testimonials_on_product_id_and_position"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.datetime "locked_at"
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "admin", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "webhook_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.string "event_type", null: false
    t.string "external_id", null: false
    t.jsonb "headers", default: {}, null: false
    t.uuid "order_id"
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.string "provider", null: false
    t.boolean "signature_valid", default: false, null: false
    t.string "status", default: "received", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_webhook_events_on_created_at"
    t.index ["order_id"], name: "index_webhook_events_on_order_id"
    t.index ["provider", "external_id"], name: "index_webhook_events_on_provider_and_external_id", unique: true
    t.index ["status"], name: "index_webhook_events_on_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "benefits", "products"
  add_foreign_key "download_tokens", "orders"
  add_foreign_key "faqs", "products"
  add_foreign_key "message_logs", "clients"
  add_foreign_key "message_logs", "orders"
  add_foreign_key "orders", "clients"
  add_foreign_key "orders", "products"
  add_foreign_key "page_visits", "products"
  add_foreign_key "sessions", "users"
  add_foreign_key "testimonials", "products"
  add_foreign_key "webhook_events", "orders"
end
