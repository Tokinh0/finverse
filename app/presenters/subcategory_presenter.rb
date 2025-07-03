# app/presenters/category_presenter.rb
class SubcategoryPresenter
  def initialize(subcategory)
    @subcategory = subcategory
  end

  def as_json(_options = {})
    {
      id: @subcategory.id,
      name: @subcategory.name,
      color_code: @subcategory.color_code,
      category: {
        id: @subcategory.category.id,
        name: @subcategory.category.name,
        color_code: @subcategory.category.color_code
      }
    }
  end
end
