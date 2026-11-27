# Assigns a subcategory and transaction type to a parsed statement entry.
#
# Build one instance per import and call it for every row: keywords and the "Outros"
# fallback subcategory are loaded once, on first use.
class Categorization
  def self.call(entry)
    new.call(entry)
  end

  def call(entry)
    match = Matchers::DefaultMatcher.find_best_keyword_match(entry[:name], keywords)
    subcategory_id = match&.subcategory_id || fallback_subcategory.id

    {
      name: entry[:name],
      amount: entry[:amount],
      subcategory_id: subcategory_id,
      transaction_date: entry[:transaction_date],
      transaction_type: entry[:transaction_type] || infer_transaction_type(entry)
    }
  end

  private

  def keywords
    @keywords ||= Keyword.all.to_a
  end

  def fallback_subcategory
    @fallback_subcategory ||= Subcategory.other_subcategory
  end

  def infer_transaction_type(entry)
    return :debit if entry[:amount] < 0

    Keywords::TypeInference.call(StringUtils.default_string_parse(entry[:name]))
  end
end
