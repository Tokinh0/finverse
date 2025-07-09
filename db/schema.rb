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

ActiveRecord::Schema[7.1].define(version: 2025_07_02_010122) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.string "parsed_name"
    t.string "color_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["subcategory_id"], name: "index_keywords_on_subcategory_id"
  end

  create_table "monthly_statements", force: :cascade do |t|
    t.string "status", default: "unprocessed"
    t.date "first_transaction_date"
    t.date "last_transaction_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "subcategories", force: :cascade do |t|
    t.string "name"
    t.string "parsed_name"
    t.string "color_code"
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_subcategories_on_category_id"
  end

  create_table "summary_lines", force: :cascade do |t|
    t.string "status"
    t.string "error"
    t.string "content"
    t.bigint "monthly_statement_id", null: false
    t.bigint "parsed_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["monthly_statement_id"], name: "index_summary_lines_on_monthly_statement_id"
    t.index ["parsed_transaction_id"], name: "index_summary_lines_on_parsed_transaction_id"
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
    t.index ["monthly_statement_id"], name: "index_transactions_on_monthly_statement_id"
    t.index ["subcategory_id"], name: "index_transactions_on_subcategory_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "keywords", "subcategories"
  add_foreign_key "subcategories", "categories"
  add_foreign_key "summary_lines", "monthly_statements"
  add_foreign_key "summary_lines", "transactions", column: "parsed_transaction_id"
  add_foreign_key "transactions", "monthly_statements"
  add_foreign_key "transactions", "subcategories"
end
