class SummaryLinePresenter
  def initialize(summary_line)
    @summary_line = summary_line
  end

  def as_json(*)
    {
      id: @summary_line.id,
      status: @summary_line.status,
      error: @summary_line.error,
      content: @summary_line.content,
      parsed_transaction: {
        name: @summary_line.parsed_transaction&.name,
        parsed_name: @summary_line.parsed_transaction&.parsed_name,
        amount: @summary_line.parsed_transaction&.amount&.to_f,
        transaction_date: @summary_line.parsed_transaction&.transaction_date,
        category_name: @summary_line.parsed_transaction&.subcategory&.category&.name,
        subcategory_name: @summary_line.parsed_transaction&.subcategory&.name,
        transaction_type: @summary_line.parsed_transaction&.transaction_type
      }
    }
  end
end
