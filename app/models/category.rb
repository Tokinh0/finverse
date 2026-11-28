class Category < ApplicationRecord
  include ProfileOwned
  include Normalizer

  FALLBACK_NAME = "OUTROS".freeze

  has_many :subcategories, dependent: :destroy

  validates :name, presence: true
  validates :parsed_name, uniqueness: { scope: :profile_id }

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

    errors.add(:base, I18n.t("fallback.category_undeletable"))
    throw :abort
  end
end
