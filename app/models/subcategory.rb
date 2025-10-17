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
      category = Category.other_category
      subcategory = Subcategory.find_by(parsed_name: 'OUTROS', category_id: category.id)
      raise '❌ Failed to create/find Subcategory. Check validations or DB constraints.' if subcategory.nil?
    
      subcategory
    end    
  end
end
