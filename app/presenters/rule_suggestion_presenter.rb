# A rule suggestion with a live preview of the transactions it would move.
class RuleSuggestionPresenter
  def initialize(suggestion, subcategories:, preview_limit: Rules::Preview::DEFAULT_LIMIT)
    @suggestion = suggestion
    @subcategories = subcategories
    @preview_limit = preview_limit
  end

  def as_json(*)
    keyword = @suggestion.keyword
    {
      id: @suggestion.id,
      action: @suggestion.action,
      origin: @suggestion.origin,
      status: @suggestion.status,
      confidence: @suggestion.confidence.to_f,
      reason: @suggestion.reason,
      keyword: keyword && { id: keyword.id, name: keyword.name, subcategory: subcategory(keyword.subcategory_id), **amounts(keyword) },
      proposed: @suggestion.action == "delete" ? nil : { name: @suggestion.name, subcategory: subcategory(@suggestion.subcategory_id), **amounts(@suggestion) },
      preview: @suggestion.pending? ? preview : nil,
      created_at: @suggestion.created_at
    }
  end

  private

  def preview
    result = Rules::Preview.call(@suggestion.change, limit: @preview_limit)
    {
      counts: result.counts,
      total: result.total,
      matched: result.matched,
      transactions: result.rows.map do |row|
        transaction = row.transaction
        {
          id: transaction.id, name: transaction.name, amount: transaction.amount.to_f,
          transaction_date: transaction.transaction_date&.to_date&.iso8601,
          categorization_source: transaction.categorization_source, kept: row.kept,
          from: subcategory(row.from_subcategory_id), to: subcategory(row.to_subcategory_id)
        }
      end
    }
  end

  def amounts(record)
    { min_amount: record.min_amount&.to_f, max_amount: record.max_amount&.to_f }
  end

  def subcategory(id)
    found = @subcategories[id]
    found && { id: found.id, name: found.name, category: found.category.name, color_code: found.color_code }
  end
end
