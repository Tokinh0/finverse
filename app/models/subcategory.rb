class Subcategory < ApplicationRecord
  include Searchable

  belongs_to :category
  has_many :transactions
  has_many :keywords, dependent: :destroy

  validates :name, presence: true
  validates :parsed_name, uniqueness: { scope: :category_id }


  class << self
    def other_subcategory
      Subcategory.find_or_create_by!(name: 'Others', category: Category.other_category)
    end
  end
end
