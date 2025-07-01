class Subcategory < ApplicationRecord
  belongs_to :category
  has_many :transactions
  has_many :keywords, dependent: :destroy

  validates :name, presence: true

  after_initialize :set_parsed_name

  def set_parsed_name
    self.parsed_name = name&.parameterize&.upcase
  end

  class << self
    def other_subcategory
      Subcategory.find_or_create_by!(parsed_name: 'OTHERS', category: Category.other_category)
    end
  end
end
