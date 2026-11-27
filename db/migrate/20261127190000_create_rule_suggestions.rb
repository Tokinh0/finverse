# Proposed changes to the keyword rules: create a rule, change one (keyword text and/or
# subcategory) or delete one. They come from local heuristics (repeated manual corrections,
# rules the owner keeps overriding) or from Claude, and only take effect when accepted.
class CreateRuleSuggestions < ActiveRecord::Migration[7.1]
  def change
    create_table :rule_suggestions do |t|
      t.string :action, null: false
      t.references :keyword, foreign_key: { on_delete: :cascade }
      t.string :name
      t.string :parsed_name
      t.references :subcategory, foreign_key: { on_delete: :cascade }
      t.references :suggestion_run, foreign_key: { on_delete: :nullify }
      t.string :origin, null: false
      t.decimal :confidence, precision: 3, scale: 2, null: false
      t.string :reason
      t.string :status, null: false, default: "pending"
      t.string :fingerprint, null: false
      # How many transactions the change would have matched when the owner decided. A rejected
      # change is proposed again only if that number grows a lot.
      t.integer :match_count_at_decision
      t.datetime :decided_at
      t.timestamps
    end
    add_index :rule_suggestions, %i[fingerprint status]
    add_column :suggestion_runs, :rule_suggestions_count, :integer, null: false, default: 0
  end
end
