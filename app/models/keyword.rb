class Keyword < ApplicationRecord
  include Normalizer

  belongs_to :subcategory

  validates :name, presence: true
  validates :parsed_name, uniqueness: { scope: :subcategory_id }

  enum keyword_type: { debit: "debit", credit: "credit", unknown: "unknown", ignored: "ignored" }

  after_initialize :set_keyword_type, if: -> { new_record? && keyword_type.nil? }

  delegate :category, to: :subcategory

  def set_keyword_type
    self.keyword_type = Keywords::TypeInference.call(parsed_name)
  end
end
