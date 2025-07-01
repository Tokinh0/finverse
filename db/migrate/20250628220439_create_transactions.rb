class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|
      t.decimal :amount
      t.string :name
      t.string :parsed_name
      t.string :description
      t.datetime :transaction_date
      t.string :transaction_type
      t.references :subcategory, null: false, foreign_key: true
      t.references :monthly_statement, null: false, foreign_key: true

      t.timestamps
    end
  end
end
