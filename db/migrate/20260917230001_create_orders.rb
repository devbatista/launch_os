class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders, id: :uuid do |t|
      t.references :client,  type: :uuid, foreign_key: true              # nulo até o capture trazer o pagador
      t.references :product, type: :uuid, foreign_key: true, null: false
      t.string  :status, null: false, default: "pending"
      t.integer :amount_cents, null: false                               # copiado de product.price_cents
      t.string  :currency, null: false, limit: 3
      t.string  :paypal_order_id
      t.string  :paypal_capture_id
      t.string  :payer_email
      t.string  :payer_name
      t.string  :phone                                                   # E.164 informado no checkout
      t.boolean :whatsapp_opt_in, null: false, default: false            # snapshot do checkout

      # Atribuição (spec 10), copiada do cookie lo_attr na criação
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_content
      t.string :utm_term
      t.string :fbclid
      t.string :fbp
      t.string :fbc
      t.string :landing_path
      t.string :referrer
      t.string :user_agent
      t.string :ip_address

      t.string :event_id, null: false                                    # dedup Pixel/CAPI
      t.datetime :paid_at
      t.datetime :failed_at
      t.datetime :refunded_at
      t.datetime :disputed_at
      t.datetime :purchase_tracked_at

      t.timestamps
    end

    add_index :orders, :paypal_order_id, unique: true
    add_index :orders, :paypal_capture_id, unique: true
    add_index :orders, :status
    add_index :orders, :created_at
  end
end
