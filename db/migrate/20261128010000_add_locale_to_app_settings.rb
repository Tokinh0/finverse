# The app's language ("en" or "pt-BR"): the UI, the API's messages and the reasons Claude writes.
class AddLocaleToAppSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :app_settings, :locale, :string, null: false, default: "en"
  end
end
