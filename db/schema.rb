# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_11_28_060000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_accounts_on_lower_email", unique: true, where: "(email IS NOT NULL)"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "alert_dismissals", force: :cascade do |t|
    t.bigint "parsed_transaction_id", null: false
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "profile_id", null: false
    t.index ["parsed_transaction_id", "kind"], name: "index_alert_dismissals_on_parsed_transaction_id_and_kind", unique: true
    t.index ["parsed_transaction_id"], name: "index_alert_dismissals_on_parsed_transaction_id"
    t.index ["profile_id"], name: "index_alert_dismissals_on_profile_id"
  end

  create_table "app_settings", force: :cascade do |t|
    t.text "claude_api_key"
    t.string "claude_model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id"
    t.text "brapi_token"
    t.index ["account_id"], name: "index_app_settings_on_account_id", unique: true
  end

  create_table "assets", force: :cascade do |t|
    t.string "asset_type"
    t.string "ticker"
    t.string "description"
    t.decimal "current_value"
    t.integer "rating"
    t.float "quantity"
    t.string "color_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "last_uploaded_unit_value", precision: 20, scale: 8
    t.bigint "profile_id", null: false
    t.index ["profile_id"], name: "index_assets_on_profile_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.string "parsed_name"
    t.string "color_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "profile_id", null: false
    t.index ["profile_id"], name: "index_categories_on_profile_id"
  end

  create_table "categorization_events", force: :cascade do |t|
    t.bigint "parsed_transaction_id", null: false
    t.bigint "from_subcategory_id"
    t.bigint "to_subcategory_id"
    t.string "from_source", null: false
    t.string "to_source", null: false
    t.bigint "overridden_keyword_id"
    t.string "merchant_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "note", limit: 300
    t.bigint "profile_id", null: false
    t.index ["from_subcategory_id"], name: "index_categorization_events_on_from_subcategory_id"
    t.index ["merchant_key"], name: "index_categorization_events_on_merchant_key"
    t.index ["overridden_keyword_id"], name: "index_categorization_events_on_overridden_keyword_id"
    t.index ["parsed_transaction_id"], name: "index_categorization_events_on_parsed_transaction_id"
    t.index ["profile_id"], name: "index_categorization_events_on_profile_id"
    t.index ["to_subcategory_id"], name: "index_categorization_events_on_to_subcategory_id"
  end

  create_table "category_suggestions", force: :cascade do |t|
    t.bigint "parsed_transaction_id", null: false
    t.bigint "subcategory_id", null: false
    t.bigint "suggestion_run_id"
    t.string "origin", null: false
    t.decimal "confidence", precision: 3, scale: 2, null: false
    t.string "reason"
    t.string "status", default: "pending", null: false
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "profile_id", null: false
    t.index ["parsed_transaction_id"], name: "index_category_suggestions_on_parsed_transaction_id"
    t.index ["parsed_transaction_id"], name: "index_category_suggestions_one_pending_per_transaction", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["profile_id"], name: "index_category_suggestions_on_profile_id"
    t.index ["status"], name: "index_category_suggestions_on_status"
    t.index ["subcategory_id"], name: "index_category_suggestions_on_subcategory_id"
    t.index ["suggestion_run_id"], name: "index_category_suggestions_on_suggestion_run_id"
  end

  create_table "keywords", force: :cascade do |t|
    t.string "name"
    t.string "parsed_name"
    t.string "color_code"
    t.string "description"
    t.string "keyword_type"
    t.bigint "subcategory_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "min_amount", precision: 12, scale: 2
    t.decimal "max_amount", precision: 12, scale: 2
    t.bigint "profile_id", null: false
    t.index ["profile_id"], name: "index_keywords_on_profile_id"
    t.index ["subcategory_id"], name: "index_keywords_on_subcategory_id"
  end

  create_table "monthly_statements", force: :cascade do |t|
    t.string "status", default: "unprocessed"
    t.date "first_transaction_date"
    t.date "last_transaction_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "statement_kind"
    t.bigint "profile_id", null: false
    t.index ["profile_id"], name: "index_monthly_statements_on_profile_id"
  end

  create_table "profile_sessions", force: :cascade do |t|
    t.bigint "profile_id", null: false
    t.string "token_digest", null: false
    t.datetime "last_used_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_profile_sessions_on_profile_id"
    t.index ["token_digest"], name: "index_profile_sessions_on_token_digest", unique: true
  end

  create_table "profiles", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "password_digest"
    t.string "locale", default: "en", null: false
    t.string "color_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "account_id, lower((name)::text)", name: "index_profiles_on_account_id_and_lower_name", unique: true
    t.index ["account_id"], name: "index_profiles_on_account_id"
  end

  create_table "rule_suggestions", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "keyword_id"
    t.string "name"
    t.string "parsed_name"
    t.bigint "subcategory_id"
    t.bigint "suggestion_run_id"
    t.string "origin", null: false
    t.decimal "confidence", precision: 3, scale: 2, null: false
    t.string "reason"
    t.string "status", default: "pending", null: false
    t.string "fingerprint", null: false
    t.integer "match_count_at_decision"
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "min_amount", precision: 12, scale: 2
    t.decimal "max_amount", precision: 12, scale: 2
    t.bigint "profile_id", null: false
    t.index ["fingerprint", "status"], name: "index_rule_suggestions_on_fingerprint_and_status"
    t.index ["keyword_id"], name: "index_rule_suggestions_on_keyword_id"
    t.index ["profile_id"], name: "index_rule_suggestions_on_profile_id"
    t.index ["subcategory_id"], name: "index_rule_suggestions_on_subcategory_id"
    t.index ["suggestion_run_id"], name: "index_rule_suggestions_on_suggestion_run_id"
  end

  create_table "subcategories", force: :cascade do |t|
    t.string "name"
    t.string "parsed_name"
    t.string "color_code"
    t.string "subcategory_type"
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "profile_id", null: false
    t.index ["category_id"], name: "index_subcategories_on_category_id"
    t.index ["profile_id"], name: "index_subcategories_on_profile_id"
  end

  create_table "suggestion_runs", force: :cascade do |t|
    t.bigint "monthly_statement_id"
    t.string "status", default: "queued", null: false
    t.string "error_code"
    t.string "error_message"
    t.string "model"
    t.integer "history_suggestions_count", default: 0, null: false
    t.integer "ai_groups_sent", default: 0, null: false
    t.integer "ai_suggestions_count", default: 0, null: false
    t.integer "ai_requests_count", default: 0, null: false
    t.integer "input_tokens", default: 0, null: false
    t.integer "output_tokens", default: 0, null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "rule_suggestions_count", default: 0, null: false
    t.bigint "profile_id", null: false
    t.index ["monthly_statement_id"], name: "index_suggestion_runs_on_monthly_statement_id"
    t.index ["profile_id"], name: "index_suggestion_runs_on_profile_id"
  end

  create_table "summary_lines", force: :cascade do |t|
    t.string "status"
    t.string "error"
    t.string "content"
    t.bigint "monthly_statement_id", null: false
    t.bigint "parsed_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "profile_id", null: false
    t.index ["monthly_statement_id"], name: "index_summary_lines_on_monthly_statement_id"
    t.index ["parsed_transaction_id"], name: "index_summary_lines_on_parsed_transaction_id"
    t.index ["profile_id"], name: "index_summary_lines_on_profile_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.decimal "amount"
    t.string "name"
    t.string "parsed_name"
    t.string "description"
    t.datetime "transaction_date"
    t.string "transaction_type"
    t.bigint "subcategory_id", null: false
    t.bigint "monthly_statement_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "categorization_source", default: "uncategorized", null: false
    t.bigint "keyword_id"
    t.datetime "unknown_marked_at"
    t.bigint "profile_id", null: false
    t.index ["categorization_source"], name: "index_transactions_on_categorization_source"
    t.index ["keyword_id"], name: "index_transactions_on_keyword_id"
    t.index ["monthly_statement_id"], name: "index_transactions_on_monthly_statement_id"
    t.index ["profile_id"], name: "index_transactions_on_profile_id"
    t.index ["subcategory_id"], name: "index_transactions_on_subcategory_id"
    t.index ["unknown_marked_at"], name: "index_transactions_on_unknown_marked_at", where: "(unknown_marked_at IS NOT NULL)"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "alert_dismissals", "profiles"
  add_foreign_key "alert_dismissals", "transactions", column: "parsed_transaction_id", on_delete: :cascade
  add_foreign_key "app_settings", "accounts"
  add_foreign_key "assets", "profiles"
  add_foreign_key "categories", "profiles"
  add_foreign_key "categorization_events", "keywords", column: "overridden_keyword_id", on_delete: :nullify
  add_foreign_key "categorization_events", "profiles"
  add_foreign_key "categorization_events", "subcategories", column: "from_subcategory_id", on_delete: :nullify
  add_foreign_key "categorization_events", "subcategories", column: "to_subcategory_id", on_delete: :nullify
  add_foreign_key "categorization_events", "transactions", column: "parsed_transaction_id", on_delete: :cascade
  add_foreign_key "category_suggestions", "profiles"
  add_foreign_key "category_suggestions", "subcategories", on_delete: :cascade
  add_foreign_key "category_suggestions", "suggestion_runs", on_delete: :nullify
  add_foreign_key "category_suggestions", "transactions", column: "parsed_transaction_id", on_delete: :cascade
  add_foreign_key "keywords", "profiles"
  add_foreign_key "keywords", "subcategories"
  add_foreign_key "monthly_statements", "profiles"
  add_foreign_key "profile_sessions", "profiles", on_delete: :cascade
  add_foreign_key "profiles", "accounts"
  add_foreign_key "rule_suggestions", "keywords", on_delete: :cascade
  add_foreign_key "rule_suggestions", "profiles"
  add_foreign_key "rule_suggestions", "subcategories", on_delete: :cascade
  add_foreign_key "rule_suggestions", "suggestion_runs", on_delete: :nullify
  add_foreign_key "subcategories", "categories"
  add_foreign_key "subcategories", "profiles"
  add_foreign_key "suggestion_runs", "monthly_statements", on_delete: :nullify
  add_foreign_key "suggestion_runs", "profiles"
  add_foreign_key "summary_lines", "monthly_statements"
  add_foreign_key "summary_lines", "profiles"
  add_foreign_key "summary_lines", "transactions", column: "parsed_transaction_id"
  add_foreign_key "transactions", "keywords", on_delete: :nullify
  add_foreign_key "transactions", "monthly_statements"
  add_foreign_key "transactions", "profiles"
  add_foreign_key "transactions", "subcategories"
end
