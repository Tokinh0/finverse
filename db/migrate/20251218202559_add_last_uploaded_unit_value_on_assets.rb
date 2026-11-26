class AddLastUploadedUnitValueOnAssets < ActiveRecord::Migration[7.1]
  def change
    add_column :assets, :last_uploaded_unit_value, :decimal, precision: 10, scale: 2
  end
end
