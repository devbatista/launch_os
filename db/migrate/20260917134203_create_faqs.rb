class CreateFaqs < ActiveRecord::Migration[8.1]
  def change
    create_table :faqs, id: :uuid do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid, index: false
      t.string  :question, null: false
      t.text    :answer, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :faqs, [ :product_id, :position ]
  end
end
