class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients, id: :uuid do |t|
      t.string   :name
      t.string   :email, null: false
      t.string   :phone                       # E.164
      t.boolean  :whatsapp_opt_in, null: false, default: false
      t.datetime :whatsapp_opt_in_at
      t.string   :whatsapp_opt_in_text        # texto exato aceito (evidência TCPA)
      t.datetime :whatsapp_opt_out_at
      t.string   :country, limit: 2
      t.datetime :first_purchase_at
      t.datetime :last_purchase_at

      t.timestamps
    end

    add_index :clients, "lower(email)", unique: true, name: "index_clients_on_lower_email"
  end
end
