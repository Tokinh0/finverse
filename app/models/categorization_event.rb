# One decision by the owner about a transaction's subcategory: a manual move or an accepted
# suggestion. Repeated events for the same merchant are the signal for new keyword rules, and
# events that override a keyword show which rules need fixing.
class CategorizationEvent < ApplicationRecord
  include ProfileOwned
  SOURCES = Transaction.categorization_sources.keys.freeze

  belongs_to :parsed_transaction, class_name: "Transaction"
  belongs_to :from_subcategory, class_name: "Subcategory", optional: true
  belongs_to :to_subcategory, class_name: "Subcategory", optional: true
  belongs_to :overridden_keyword, class_name: "Keyword", optional: true

  validates :from_source, :to_source, inclusion: { in: SOURCES }
  validates :merchant_key, presence: true
  validates :note, length: { maximum: 300 }

  scope :with_notes, -> { where.not(note: [ nil, "" ]) }

  scope :overriding_keywords, -> { where.not(overridden_keyword_id: nil) }
end
