class CreateKeywords < ActiveRecord::Migration[7.1]
  def change
    create_table :keywords do |t|
      t.string :name
      t.string :parsed_name
      t.string :color_code
      t.string :description
      t.string :keyword_type
      t.references :subcategory, null: false, foreign_key: true

      t.timestamps
    end
  end
end
