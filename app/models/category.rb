class Category < ApplicationRecord
  has_many :subcategories, dependent: :destroy
  
  validates :name, presence: true

  after_initialize :set_parsed_name

  def set_parsed_name
    self.parsed_name = name.parameterize.upcase
  end

  class << self
    def other_category
      Category.find_or_create_by!(parsed_name: 'OTHER')
    end
  end
end
