class Transaction < ApplicationRecord
  include Normalizer

  belongs_to :subcategory
  belongs_to :monthly_statement
  has_one :summary_line, foreign_key: :parsed_transaction_id, dependent: :destroy

  enum transaction_type: { credit: 'credit', debit: 'debit', unknown: 'unknown' }

  before_save :normalize_amount

  def normalize_amount
    self.amount = amount.to_f.abs.round(2)
  end
end
