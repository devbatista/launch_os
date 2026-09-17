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

ActiveRecord::Schema[8.1].define(version: 2026_09_17_134203) do
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

  create_table "faqs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "answer", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.uuid "product_id", null: false
    t.string "question", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "position"], name: "index_faqs_on_product_id_and_position"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "benefits", "products"
  add_foreign_key "faqs", "products"
  add_foreign_key "sessions", "users"
  add_foreign_key "testimonials", "products"
end
