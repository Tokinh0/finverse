# The brapi.dev token (Brazilian stock, FII and index quotes) is shared by the account, like the
# Claude key. Unit prices get more decimals so crypto worth a few cents keeps its value.
class AddMarketDataSettings < ActiveRecord::Migration[7.1]
  def up
    add_column :app_settings, :brapi_token, :text
    change_column :assets, :last_uploaded_unit_value, :decimal, precision: 20, scale: 8
  end

  def down
    change_column :assets, :last_uploaded_unit_value, :decimal, precision: 10, scale: 2
    remove_column :app_settings, :brapi_token
  end
end
