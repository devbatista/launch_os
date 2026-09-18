class CreateWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_events, id: :uuid do |t|
      t.string  :provider, null: false                 # paypal / twilio
      t.string  :external_id, null: false              # id do evento no provedor
      t.string  :event_type, null: false
      t.jsonb   :payload, null: false, default: {}
      t.jsonb   :headers, null: false, default: {}     # só os cabeçalhos de assinatura
      t.boolean :signature_valid, null: false, default: false
      t.string  :status, null: false, default: "received"  # received / processed / ignored / failed
      t.text    :error
      t.datetime :processed_at
      t.references :order, type: :uuid, foreign_key: true  # preenchido após correlação

      t.timestamps
    end

    add_index :webhook_events, %i[provider external_id], unique: true  # chave de idempotência
    add_index :webhook_events, :status
    add_index :webhook_events, :created_at
  end
end
