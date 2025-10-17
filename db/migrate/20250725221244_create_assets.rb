class CreateAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :assets do |t|
      t.string :asset_type
      t.string :ticker
      t.string :description
      t.decimal :current_value
      t.integer :rating
      t.float :quantity
      t.string :color_code
      t.location :string

      t.timestamps
    end
  end
end
