class Subcategory < ApplicationRecord
  include Normalizer

  FALLBACK_NAME = "OUTROS".freeze

  belongs_to :category
  has_many :transactions
  has_many :keywords, dependent: :destroy

  validates :name, presence: true
  validates :parsed_name, uniqueness: { scope: :category_id }

  enum subcategory_type: {
    gain: "gain", expense: "expense", investment: "investment", transfer: "transfer", other: "other"
  }

  # Transactions must always have a subcategory, so deleting one moves its transactions
  # to the "Outros" fallback first. The fallback itself cannot be deleted.
  before_destroy :move_transactions_to_fallback, prepend: true

  class << self
    def other_subcategory
      subcategory = Category.other_category&.subcategories&.find_by(parsed_name: FALLBACK_NAME)
      raise 'Fallback Subcategory "Outros" (category "Outros") not found. Run db:seed.' if subcategory.nil?

      subcategory
    end
  end

  def fallback?
    parsed_name == FALLBACK_NAME && category&.fallback?
  end

  private

  def move_transactions_to_fallback
    if fallback?
      errors.add(:base, 'The "Outros" fallback subcategory cannot be deleted')
      throw :abort
    end
    return unless transactions.exists?

    transactions.update_all(
      subcategory_id: self.class.other_subcategory.id, categorization_source: "uncategorized", keyword_id: nil,
      updated_at: Time.current
    )
  rescue RuntimeError => e
    errors.add(:base, "Cannot move this subcategory's transactions: #{e.message}")
    throw :abort
  end
end
