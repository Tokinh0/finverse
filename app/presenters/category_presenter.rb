# app/presenters/category_presenter.rb
class CategoryPresenter
  def initialize(category)
    @category = category
  end

  def as_json(_options = {})
    {
      id: @category.id,
      name: @category.name,
      color_code: @category.color_code,
      subcategories: @category.subcategories.map do |sub|
        {
          id: sub.id,
          name: sub.name,
          color_code: sub.color_code
        }
      end
    }
  end
end
