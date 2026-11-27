class CreateAlertDismissals < ActiveRecord::Migration[7.1]
  def change
    create_table :alert_dismissals do |t|
      t.references :parsed_transaction, null: false, foreign_key: { to_table: :transactions, on_delete: :cascade }
      t.string :kind, null: false
      t.timestamps
    end

    add_index :alert_dismissals, %i[parsed_transaction_id kind], unique: true
  end
end
