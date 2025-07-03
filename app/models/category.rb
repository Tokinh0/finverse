class Category < ApplicationRecord
  include Searchable

  has_many :subcategories, dependent: :destroy
  
  validates :name, presence: true
  validates :parsed_name, uniqueness: true

  class << self
    def other_category
      Category.find_or_create_by!(name: 'Other')
    end
  end
end
