class Subcategory < ApplicationRecord
  include Normalizer

  belongs_to :category
  has_many :transactions
  has_many :keywords, dependent: :destroy

  validates :name, presence: true
  validates :parsed_name, uniqueness: { scope: :category_id }

  enum subcategory_type: { 
    gain: 'gain', expense: 'expense', investment: 'investment', transfer: 'transfer', other: 'other' 
  }

  class << self
    def other_subcategory
      subcategory = Category.other_category&.subcategories&.find_by(parsed_name: 'OUTROS')
      raise 'Fallback Subcategory "Outros" (category "Outros") not found. Run db:seed.' if subcategory.nil?

      subcategory
    end
  end
end
