class Category < ApplicationRecord
  include Normalizer

  has_many :subcategories, dependent: :destroy
  
  validates :name, presence: true
  validates :parsed_name, uniqueness: true

  class << self
    def other_category
      Category.find_by(parsed_name: 'OUTROS')
    end
  end
end
