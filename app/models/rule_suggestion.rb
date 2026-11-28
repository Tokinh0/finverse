# A proposed change to the keyword rules. See Rules::Change for what each action does.
#
# The fingerprint identifies "the same change" across runs, so a pending one isn't duplicated
# and a rejected one isn't proposed again unless the data changed a lot (Rules::Rejections).
class RuleSuggestion < ApplicationRecord
  include ProfileOwned
  include Normalizer

  ACTIONS = %w[create update delete].freeze

  belongs_to :keyword, optional: true
  belongs_to :subcategory, optional: true
  belongs_to :suggestion_run, optional: true

  enum origin: { local: "local", ai: "ai" }, _prefix: :from
  enum status: { pending: "pending", accepted: "accepted", rejected: "rejected", superseded: "superseded" }

  validates :action, inclusion: { in: ACTIONS }
  validates :confidence, numericality: { in: 0..1 }
  validates :name, presence: true, unless: -> { action == "delete" }
  validates :subcategory, presence: true, unless: -> { action == "delete" }
  validates :keyword, presence: true, unless: -> { action == "create" }

  before_validation { self.fingerprint = change.fingerprint }

  def change
    Rules::Change.new(action: action, keyword: keyword, name: name, subcategory_id: subcategory_id,
                      min_amount: min_amount, max_amount: max_amount)
  end
end
