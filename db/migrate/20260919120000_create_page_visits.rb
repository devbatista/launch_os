class CreatePageVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :page_visits, id: :uuid do |t|
      t.references :product, type: :uuid, foreign_key: true, index: false
      t.string :path, null: false
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_content
      t.string :utm_term
      t.string :fbclid
      t.string :referrer
      t.string :user_agent
      t.string :ip_hash
      t.string :visitor_id

      t.timestamps
    end

    add_index :page_visits, [ :product_id, :created_at ]
    add_index :page_visits, :created_at
    add_index :page_visits, :visitor_id
  end
end
