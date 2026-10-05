# Métricas diárias por anúncio vindas do Insights da Meta (spec 16, Marketing API — Insights). Uma linha por
# (anúncio, dia), regravada a cada sync enquanto a atribuição da Meta ainda pode mudar. O `ad_name` segue a
# convenção do briefing (= `utm_content`), que é a ponte com os `Orders`.
#
# `purchases` é o que a Meta atribui ao anúncio — referência, não verdade: venda é `Order` pago.
class CreateAdInsights < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_insights, id: :uuid do |t|
      t.date :date, null: false                       # dia no fuso da conta de anúncios
      t.string :meta_ad_id, null: false
      t.string :ad_name, null: false
      t.string :meta_campaign_id
      t.string :campaign_name
      t.integer :spend_cents, null: false, default: 0 # na moeda da conta (`currency`)
      t.string :currency, limit: 3, null: false
      t.integer :impressions, null: false, default: 0
      t.integer :link_clicks, null: false, default: 0
      t.integer :landing_page_views, null: false, default: 0
      t.integer :initiate_checkouts, null: false, default: 0
      t.integer :purchases, null: false, default: 0
      t.timestamps
    end

    add_index :ad_insights, [ :meta_ad_id, :date ], unique: true
    add_index :ad_insights, :date
    add_index :ad_insights, :ad_name
  end
end
