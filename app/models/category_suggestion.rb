# A proposed subcategory for an uncategorized transaction. It never changes the transaction by
# itself: the owner accepts (as is or with another subcategory) or rejects it.
#
# origin: "history" (the owner already categorized this merchant) or "ai" (Claude).
# status: pending → accepted / rejected, or superseded when the transaction was categorized
# some other way first.
class CategorySuggestion < ApplicationRecord
  belongs_to :parsed_transaction, class_name: "Transaction"
  belongs_to :subcategory
  belongs_to :suggestion_run, optional: true

  enum origin: { history: "history", ai: "ai" }, _prefix: :from
  enum status: { pending: "pending", accepted: "accepted", rejected: "rejected", superseded: "superseded" }

  validates :confidence, numericality: { in: 0..1 }
  validates :parsed_transaction_id, uniqueness: { conditions: -> { pending } }, if: :pending?
end
