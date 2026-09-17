class CreateTestimonials < ActiveRecord::Migration[8.1]
  def change
    create_table :testimonials, id: :uuid do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid, index: false
      t.string  :author_name, null: false
      t.string  :author_role
      t.text    :quote, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :testimonials, [ :product_id, :position ]
  end
end
