class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products, id: :uuid do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.string  :headline, null: false
      t.string  :subheadline
      t.text    :problem_text
      t.integer :price_cents, null: false
      t.integer :compare_at_price_cents
      t.string  :currency, null: false, default: "USD", limit: 3
      t.string  :status, null: false, default: "draft"
      t.string  :template, null: false, default: "direct_response"
      t.string  :meta_title
      t.string  :meta_description
      t.text    :guarantee_text
      t.integer :refund_days, null: false, default: 14
      t.datetime :published_at
      t.string :cta_text, null: false, default: "Buy Now"

      t.timestamps
    end

    add_index :products, :slug, unique: true
    add_index :products, :status
  end
end
