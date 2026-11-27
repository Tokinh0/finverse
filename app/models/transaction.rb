class Transaction < ApplicationRecord
  include Normalizer

  belongs_to :subcategory
  belongs_to :keyword, optional: true
  belongs_to :monthly_statement
  has_one :summary_line, foreign_key: :parsed_transaction_id, dependent: :destroy
  has_many :alert_dismissals, foreign_key: :parsed_transaction_id, dependent: :delete_all
  has_many :categorization_events, foreign_key: :parsed_transaction_id, dependent: :delete_all

  enum transaction_type: { credit: "credit", debit: "debit", unknown: "unknown" }

  # How the current subcategory was chosen. "uncategorized" means it is still in the Outros
  # fallback because no keyword matched and nobody picked one.
  enum categorization_source: {
    keyword: "keyword", ai_accepted: "ai_accepted", manual: "manual", uncategorized: "uncategorized"
  }, _prefix: :categorized_by

  before_save :normalize_amount

  def normalize_amount
    self.amount = amount.to_f.abs.round(2)
  end
end
