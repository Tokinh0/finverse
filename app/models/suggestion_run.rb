# One pass of the suggestion pipeline (Suggestions::Generate), after an import or on request.
class SuggestionRun < ApplicationRecord
  belongs_to :monthly_statement, optional: true
  has_many :category_suggestions, dependent: :nullify
  has_many :rule_suggestions, dependent: :nullify

  enum status: { queued: "queued", running: "running", succeeded: "succeeded", failed: "failed" }

  scope :in_progress, -> { where(status: %w[queued running]) }
end
