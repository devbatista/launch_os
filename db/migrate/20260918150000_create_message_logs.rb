class CreateMessageLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :message_logs, id: :uuid do |t|
      t.references :order, type: :uuid, foreign_key: true, null: false, index: false
      t.references :client, type: :uuid, foreign_key: true
      t.string   :channel, null: false
      t.string   :template, null: false
      t.string   :recipient, null: false
      t.string   :provider_message_id
      t.string   :status, null: false, default: "queued"
      t.string   :error_code
      t.text     :error_message
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :read_at
      t.datetime :failed_at
      t.integer  :attempts, null: false, default: 0

      t.timestamps
    end

    add_index :message_logs, :provider_message_id
    add_index :message_logs, [ :order_id, :created_at ]
    add_index :message_logs, :status
    add_index :message_logs, :created_at
  end
end
