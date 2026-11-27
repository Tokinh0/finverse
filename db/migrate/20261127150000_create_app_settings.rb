# App-wide settings (Finverse has a single owner). Holds the owner's Claude API key, encrypted.
class CreateAppSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :app_settings do |t|
      t.text :claude_api_key
      t.string :claude_model
      t.timestamps
    end
  end
end
