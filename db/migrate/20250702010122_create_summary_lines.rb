class CreateSummaryLines < ActiveRecord::Migration[7.1]
  def change
    create_table :summary_lines do |t|
      t.string :status
      t.string :error
      t.string :content
      t.references :monthly_statement, null: false, foreign_key: true
      t.references :parsed_transaction, foreign_key: { to_table: :transactions }

      t.timestamps
    end
  end
end
