class Keyword < ApplicationRecord
  belongs_to :subcategory

  validates :name, presence: true

  after_initialize :set_parsed_name

  def set_parsed_name
    self.parsed_name = name.parameterize.upcase
  end
end
