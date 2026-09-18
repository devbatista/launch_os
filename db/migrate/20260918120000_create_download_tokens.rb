class CreateDownloadTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :download_tokens, id: :uuid do |t|
      t.references :order, type: :uuid, foreign_key: true, null: false, index: { unique: true }
      t.string   :token, null: false
      t.datetime :expires_at, null: false
      t.integer  :download_count, null: false, default: 0
      t.integer  :max_downloads, null: false, default: 10
      t.datetime :revoked_at
      t.datetime :last_downloaded_at

      t.timestamps
    end

    add_index :download_tokens, :token, unique: true
  end
end
