class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories do |t|
      t.string :name
      t.string :parsed_name
      t.string :color_code

      t.timestamps
    end
  end
end
