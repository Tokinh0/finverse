class Transaction < ApplicationRecord
  include Searchable

  belongs_to :subcategory, optional: true
  belongs_to :monthly_statement, optional: true
  has_one :summary_line, foreign_key: :parsed_transaction_id, dependent: :destroy

  enum transaction_type: { credit: 'credit', debit: 'debit', unknown: 'unknown' }

  scope :by_month_and_year, -> (month, year) { 
    where(
      transaction_date: DateTime.new(year.to_i, month.to_i).beginning_of_month..DateTime.new(year.to_i, month.to_i).end_of_month
    ) 
  }
end
