# Accounts, profiles and profile sessions, with every piece of data owned by a profile.
#
# An account (the future email login) has a few profiles, one per person using the app. All the
# financial data belongs to a profile; the Claude settings belong to the account. Existing data
# moves to one profile created here (named "Principal"; rename it in the app).
class CreateAccountsAndProfiles < ActiveRecord::Migration[7.1]
  PROFILE_TABLES = %i[
    categories subcategories keywords monthly_statements transactions summary_lines assets alert_dismissals
    categorization_events category_suggestions rule_suggestions suggestion_runs
  ].freeze

  def up
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :email
      t.timestamps
    end
    add_index :accounts, "lower(email)", unique: true, where: "email IS NOT NULL", name: "index_accounts_on_lower_email"

    create_table :profiles do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :password_digest
      t.string :locale, null: false, default: "en"
      t.string :color_code
      t.timestamps
    end
    add_index :profiles, "account_id, lower(name)", unique: true, name: "index_profiles_on_account_id_and_lower_name"

    create_table :profile_sessions do |t|
      t.references :profile, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_digest, null: false, index: { unique: true }
      t.datetime :last_used_at, null: false
      t.timestamps
    end

    add_reference :app_settings, :account, foreign_key: true, index: { unique: true }
    PROFILE_TABLES.each { |table| add_reference table, :profile, foreign_key: true }

    move_existing_data
    PROFILE_TABLES.each { |table| change_column_null table, :profile_id, false }
    remove_column :app_settings, :locale
  end

  def down
    add_column :app_settings, :locale, :string, default: "en", null: false
    execute <<~SQL
      UPDATE app_settings SET locale = COALESCE((SELECT locale FROM profiles ORDER BY id LIMIT 1), 'en')
    SQL
    PROFILE_TABLES.each { |table| remove_reference table, :profile, foreign_key: true }
    remove_reference :app_settings, :account, foreign_key: true
    drop_table :profile_sessions
    drop_table :profiles
    drop_table :accounts
  end

  private

  def move_existing_data
    return unless (PROFILE_TABLES + [ :app_settings ]).any? { |table| select_value("SELECT 1 FROM #{table} LIMIT 1") }

    locale = select_value("SELECT locale FROM app_settings ORDER BY id LIMIT 1") || "en"
    account_id = select_value(<<~SQL)
      INSERT INTO accounts (name, created_at, updated_at) VALUES ('Finverse', now(), now()) RETURNING id
    SQL
    profile_id = select_value(<<~SQL)
      INSERT INTO profiles (account_id, name, locale, created_at, updated_at)
      VALUES (#{account_id}, 'Principal', #{quote(locale)}, now(), now()) RETURNING id
    SQL

    PROFILE_TABLES.each { |table| execute("UPDATE #{table} SET profile_id = #{profile_id}") }
    execute("DELETE FROM app_settings WHERE id <> (SELECT min(id) FROM app_settings)")
    execute("UPDATE app_settings SET account_id = #{account_id}")
  end
end
