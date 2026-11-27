class CategorySuggestionPresenter
  def initialize(suggestion, include_transaction: true)
    @suggestion = suggestion
    @include_transaction = include_transaction
  end

  def as_json(*)
    subcategory = @suggestion.subcategory
    {
      id: @suggestion.id,
      origin: @suggestion.origin,
      status: @suggestion.status,
      confidence: @suggestion.confidence.to_f,
      reason: @suggestion.reason,
      subcategory: { id: subcategory.id, name: subcategory.name, color_code: subcategory.color_code },
      category: { id: subcategory.category.id, name: subcategory.category.name, color_code: subcategory.category.color_code },
      merchant_key: Transactions::Merchant.key(@suggestion.parsed_transaction),
      transaction: @include_transaction ? TransactionPresenter.new(@suggestion.parsed_transaction, include_suggestion: false) : nil
    }.compact
  end
end
