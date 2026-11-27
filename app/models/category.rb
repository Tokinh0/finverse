class Category < ApplicationRecord
  include Normalizer

  FALLBACK_NAME = 'OUTROS'.freeze

  has_many :subcategories, dependent: :destroy

  validates :name, presence: true
  validates :parsed_name, uniqueness: true

  before_destroy :prevent_fallback_destroy, prepend: true

  class << self
    def other_category
      Category.find_by(parsed_name: FALLBACK_NAME)
    end
  end

  def fallback?
    parsed_name == FALLBACK_NAME
  end

  private

  def prevent_fallback_destroy
    return unless fallback?

    errors.add(:base, 'The "Outros" fallback category cannot be deleted')
    throw :abort
  end
end
