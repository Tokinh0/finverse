# Records how each transaction got its subcategory (keyword rule, accepted suggestion, manual
# fix, or nothing: still in the "Outros" fallback), which keyword matched it, what kind of
# statement it came from, and the history of manual corrections.
class AddCategorizationTracking < ActiveRecord::Migration[7.1]
  # Minimal models so the backfill doesn't depend on app code that may change later.
  class MigrationKeyword < ActiveRecord::Base
    self.table_name = "keywords"
  end

  class MigrationTransaction < ActiveRecord::Base
    self.table_name = "transactions"
  end

  def up
    add_column :transactions, :categorization_source, :string, null: false, default: "uncategorized"
    add_reference :transactions, :keyword, foreign_key: { on_delete: :nullify }
    add_index :transactions, :categorization_source

    add_column :monthly_statements, :statement_kind, :string

    create_table :categorization_events do |t|
      t.references :parsed_transaction, null: false, foreign_key: { to_table: :transactions, on_delete: :cascade }
      t.references :from_subcategory, foreign_key: { to_table: :subcategories, on_delete: :nullify }
      t.references :to_subcategory, foreign_key: { to_table: :subcategories, on_delete: :nullify }
      t.string :from_source, null: false
      t.string :to_source, null: false
      t.references :overridden_keyword, foreign_key: { to_table: :keywords, on_delete: :nullify }
      t.string :merchant_key, null: false
      t.timestamps
    end
    add_index :categorization_events, :merchant_key

    backfill
  end

  def down
    drop_table :categorization_events
    remove_column :monthly_statements, :statement_kind
    remove_reference :transactions, :keyword, foreign_key: true
    remove_column :transactions, :categorization_source
  end

  private

  # Transactions in the fallback stay "uncategorized". Otherwise, if the keyword matcher still
  # picks the current subcategory, it came from that keyword; if not, the owner moved it by hand.
  def backfill
    fallback_ids = select_values(<<~SQL)
      SELECT s.id FROM subcategories s JOIN categories c ON c.id = s.category_id
      WHERE s.parsed_name = 'OUTROS' AND c.parsed_name = 'OUTROS'
    SQL
    keywords = MigrationKeyword.all.to_a

    MigrationTransaction.where.not(subcategory_id: fallback_ids).find_each do |transaction|
      best = keywords.map { |kw| [ kw, Matchers::DefaultMatcher.match_score(transaction.parsed_name.to_s, kw.parsed_name.to_s) ] }
                     .select { |_, score| score.positive? }
                     .max_by { |_, score| score }
                     &.first

      if best && best.subcategory_id == transaction.subcategory_id
        transaction.update_columns(categorization_source: "keyword", keyword_id: best.id)
      else
        transaction.update_columns(categorization_source: "manual")
      end
    end
  end
end
