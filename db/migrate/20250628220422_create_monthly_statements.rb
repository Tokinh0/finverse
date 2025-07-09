class CreateMonthlyStatements < ActiveRecord::Migration[7.1]
  def change
    create_table :monthly_statements do |t|
      t.string :status, default: "unprocessed"
      t.date :first_transaction_date
      t.date :last_transaction_date

      t.timestamps
    end
  end
end
