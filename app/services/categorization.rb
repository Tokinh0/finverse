class Categorization
  def initialize(new_entry)
    @new_entry = new_entry
    @keywords = Keyword.includes(subcategory: :category)
  end

  def call
    match = Matchers::DefaultMatcher.find_best_keyword_match(@new_entry[:name])

    subcategory = match&.subcategory || Subcategory.other_subcategory

    {
      name: @new_entry[:name],
      amount: @new_entry[:amount],
      subcategory_id: subcategory.id,
      transaction_date: @new_entry[:transaction_date],
      transaction_type: @new_entry[:transaction_type] || infer_transaction_type
    }
  end

  def self.call(entry)
    new(entry).call
  end

  def infer_transaction_type
    return :debit if @new_entry[:amount] < 0

    Keyword.infer_keyword_type(default_string_parse(@new_entry[:name]))
  end
end
