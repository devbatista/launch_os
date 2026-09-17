class CreateBenefits < ActiveRecord::Migration[8.1]
  def change
    create_table :benefits, id: :uuid do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid, index: false
      t.string  :title, null: false
      t.text    :description
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :benefits, [ :product_id, :position ]
  end
end
