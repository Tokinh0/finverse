class TransactionPresenter
  def initialize(transaction)
    @transaction = transaction
  end

  def as_json(*)
    subcategory = @transaction.subcategory
    category = subcategory&.category

    {
      id: @transaction.id,
      name: @transaction.name,
      parsed_name: @transaction.parsed_name,
      description: @transaction.description,
      amount: @transaction.amount.to_f,
      transaction_date: @transaction.transaction_date&.to_date&.iso8601,
      transaction_type: @transaction.transaction_type,
      categorization_source: @transaction.categorization_source,
      keyword_id: @transaction.keyword_id,
      monthly_statement_id: @transaction.monthly_statement_id,
      subcategory: subcategory && { id: subcategory.id, name: subcategory.name, color_code: subcategory.color_code },
      category: category && { id: category.id, name: category.name, color_code: category.color_code }
    }
  end
end
