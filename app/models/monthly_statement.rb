class MonthlyStatement < ApplicationRecord
  has_many :transactions, dependent: :destroy
  has_many :summary_lines, dependent: :destroy

  enum status: { unprocessed: "unprocessed", processed: "processed", failed: "failed" }
  enum statement_kind: { checking_account: "checking_account", credit_card: "credit_card" }

  has_one_attached :file
end
