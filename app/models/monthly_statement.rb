class MonthlyStatement < ApplicationRecord
  has_many :transactions, dependent: :destroy
  has_many :summary_lines, dependent: :destroy

  enum status: { unprocessed: 'unprocessed', processed: 'processed', failed: 'failed' }

  has_one_attached :file
end
