class SummaryLine < ApplicationRecord
  belongs_to :monthly_statement
  belongs_to :parsed_transaction, optional: true, class_name: "Transaction"

  enum status: { processed: 'processed', failed: 'failed', skipped: 'skipped' }
end
