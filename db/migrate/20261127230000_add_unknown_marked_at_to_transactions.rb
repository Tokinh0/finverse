# Set when the owner says "no idea" about a transaction: it stays in the Outros fallback,
# gets no more suggestions and isn't moved by rules, until the owner categorizes it or undoes it.
class AddUnknownMarkedAtToTransactions < ActiveRecord::Migration[7.1]
  def change
    add_column :transactions, :unknown_marked_at, :datetime
    add_index :transactions, :unknown_marked_at, where: "unknown_marked_at IS NOT NULL"
  end
end
