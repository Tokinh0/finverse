# Suggestions the owner reviews: a subcategory for an uncategorized transaction, found in the
# owner's own history or suggested by Claude. A run records one pass of the pipeline.
class CreateSuggestions < ActiveRecord::Migration[7.1]
  def change
    create_table :suggestion_runs do |t|
      t.references :monthly_statement, foreign_key: { on_delete: :nullify }
      t.string :status, null: false, default: "queued"
      t.string :error_code
      t.string :error_message
      t.string :model
      t.integer :history_suggestions_count, null: false, default: 0
      t.integer :ai_groups_sent, null: false, default: 0
      t.integer :ai_suggestions_count, null: false, default: 0
      t.integer :ai_requests_count, null: false, default: 0
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    create_table :category_suggestions do |t|
      t.references :parsed_transaction, null: false, foreign_key: { to_table: :transactions, on_delete: :cascade }
      t.references :subcategory, null: false, foreign_key: { on_delete: :cascade }
      t.references :suggestion_run, foreign_key: { on_delete: :nullify }
      t.string :origin, null: false
      t.decimal :confidence, precision: 3, scale: 2, null: false
      t.string :reason
      t.string :status, null: false, default: "pending"
      t.datetime :decided_at
      t.timestamps
    end
    add_index :category_suggestions, :parsed_transaction_id, unique: true, where: "status = 'pending'",
                                                             name: "index_category_suggestions_one_pending_per_transaction"
    add_index :category_suggestions, :status
  end
end
