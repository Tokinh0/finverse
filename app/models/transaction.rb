class Transaction < ApplicationRecord
  belongs_to :subcategory, optional: true
  belongs_to :monthly_statement, optional: true

  enum transaction_type: { credit: 'credit', debit: 'debit', unknown: 'unknown' }
end
