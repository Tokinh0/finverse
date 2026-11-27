# A charge alert the owner reviewed and marked as fine, so Alerts::Detector stops showing it.
class AlertDismissal < ApplicationRecord
  KINDS = %w[duplicate new_merchant amount_changed unusual_amount].freeze

  belongs_to :parsed_transaction, class_name: 'Transaction'

  validates :kind, inclusion: { in: KINDS }
  validates :kind, uniqueness: { scope: :parsed_transaction_id }
end
