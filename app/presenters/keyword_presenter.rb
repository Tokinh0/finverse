class KeywordPresenter
  def initialize(keyword)
    @keyword = keyword
  end

  def as_json(_options = {})
    {
      id: @keyword.id,
      name: @keyword.name,
      parsed_name: @keyword.parsed_name,
      description: @keyword.description,
      color_code: @keyword.color_code,
      keyword_type: @keyword.keyword_type,
      subcategory_id: @keyword.subcategory_id,
      subcategory: subcategory_payload,
      created_at: @keyword.created_at,
      updated_at: @keyword.updated_at
    }
  end

  private

  def subcategory_payload
    return nil unless @keyword.subcategory

    {
      id: @keyword.subcategory.id,
      name: @keyword.subcategory.name,
      color_code: @keyword.subcategory.color_code,
      subcategory_type: @keyword.subcategory.subcategory_type,
      category: category_payload
    }
  end

  def category_payload
    return nil unless @keyword.category

    {
      id: @keyword.category.id,
      name: @keyword.category.name,
      color_code: @keyword.category.color_code
    }
  end
end


