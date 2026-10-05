# Campanhas da Meta vistas pelo sync do Insights, com o vínculo manual a um produto (spec 16): é o que
# permite gasto, CAC e ROAS por produto no dashboard. O sync só cria/renomeia; `product_id` é definido no
# admin (Campanhas Meta). Mesma tabela que a criação via API vai usar depois.
#
# Backfill: campanhas que já aparecem em `ad_insights` entram sem produto, com o nome mais recente.
class CreateAdCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_campaigns, id: :uuid do |t|
      t.string :meta_campaign_id, null: false
      t.string :name, null: false
      t.references :product, type: :uuid, foreign_key: true
      t.timestamps
    end
    add_index :ad_campaigns, :meta_campaign_id, unique: true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO ad_campaigns (id, meta_campaign_id, name, created_at, updated_at)
          SELECT gen_random_uuid(), meta_campaign_id,
                 COALESCE((ARRAY_AGG(campaign_name ORDER BY date DESC))[1], meta_campaign_id), NOW(), NOW()
          FROM ad_insights
          WHERE meta_campaign_id IS NOT NULL
          GROUP BY meta_campaign_id
        SQL
      end
    end
  end
end
