class Transaction < ApplicationRecord
  include ProfileOwned
  include Normalizer

  belongs_to :subcategory
  belongs_to :keyword, optional: true
  belongs_to :monthly_statement
  has_one :summary_line, foreign_key: :parsed_transaction_id, dependent: :destroy
  has_many :alert_dismissals, foreign_key: :parsed_transaction_id, dependent: :delete_all
  has_many :categorization_events, foreign_key: :parsed_transaction_id, dependent: :delete_all
  has_many :category_suggestions, foreign_key: :parsed_transaction_id, dependent: :delete_all
  has_one :pending_category_suggestion, -> { pending }, class_name: "CategorySuggestion", foreign_key: :parsed_transaction_id

  enum transaction_type: { credit: "credit", debit: "debit", unknown: "unknown" }

  # How the current subcategory was chosen. "uncategorized" means it is still in the Outros
  # fallback because no keyword matched and nobody picked one.
  enum categorization_source: {
    keyword: "keyword", ai_accepted: "ai_accepted", manual: "manual", uncategorized: "uncategorized"
  }, _prefix: :categorized_by

  # "No idea": the owner can't tell what this is. See Transactions::MarkUnknown.
  scope :marked_unknown, -> { where.not(unknown_marked_at: nil) }
  scope :not_marked_unknown, -> { where(unknown_marked_at: nil) }

  before_save :normalize_amount

  def marked_unknown?
    unknown_marked_at.present?
  end

  def normalize_amount
    self.amount = amount.to_f.abs.round(2)
  end
end
