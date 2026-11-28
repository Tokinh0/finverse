class Keyword < ApplicationRecord
  include ProfileOwned
  include Normalizer

  belongs_to :subcategory
  has_many :transactions, dependent: :nullify
  has_many :rule_suggestions, dependent: :delete_all

  validates :name, presence: true
  validates :parsed_name, uniqueness: { scope: %i[subcategory_id min_amount max_amount] }
  validates :min_amount, :max_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :amount_range_order

  enum keyword_type: { debit: "debit", credit: "credit", unknown: "unknown", ignored: "ignored" }

  after_initialize :set_keyword_type, if: -> { new_record? && keyword_type.nil? }

  delegate :category, to: :subcategory

  def set_keyword_type
    self.keyword_type = Keywords::TypeInference.call(parsed_name)
  end

  # A rule with an amount range only applies to transactions whose (absolute) amount is inside
  # it, bounds included. Without an amount, ranged rules don't apply.
  def amount_range?
    min_amount.present? || max_amount.present?
  end

  def applies_to_amount?(amount)
    return true unless amount_range?
    return false if amount.nil?

    value = amount.to_d.abs
    (min_amount.nil? || value >= min_amount) && (max_amount.nil? || value <= max_amount)
  end

  private

  def amount_range_order
    return unless min_amount && max_amount && min_amount > max_amount

    errors.add(:max_amount, :below_minimum)
  end
end
