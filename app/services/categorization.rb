class Categorization
  include Searchable

  def initialize(new_entry)
    # new_entry = { name: 'MERCADO LIVRE', parsed_name: 'MERCADO-LIVRE', amount: 100.0, transaction_date: Date.today, transaction_type: 'debit' }
    @new_entry = new_entry
    @keywords = Keyword.includes(subcategory: :category)
  end

  def call
    match = find_best_keyword_match

    subcategory = match&.subcategory || Subcategory.other_subcategory

    {
      name: @new_entry[:name],
      amount: @new_entry[:amount],
      subcategory: subcategory,
      transaction_date: @new_entry[:transaction_date],
      transaction_type: @new_entry[:transaction_type] || infer_transaction_type
    }
  end

  def self.call(entry)
    new(entry).call
  end

  private

  def find_best_keyword_match
    parsed_name = default_string_parse(@new_entry[:name])
    @keywords.map { |kw| [kw, match_score(parsed_name, kw.parsed_name)] }.select { |_, score| score > 0 }.max_by { |_, score| score }&.first
  end

  def match_score(input, keyword)
    return 3 if input == keyword                     # Exact match
    return 2 if input.include?(" #{keyword} ")       # Whole word match
    return 1 if input.include?(keyword)              # Partial match
    0
  end

  def normalize(text)
    " #{text.gsub(/[^A-Z0-9]+/, ' ').strip.upcase} "
  end

  def infer_transaction_type
    return 'credit' if credit_keywords.any? { |w| @parsed_name.include?(w) }
    return 'debit' if debit_keywords.any? { |w| @parsed_name.include?(w) }
    'unknown'
  end

  def credit_keywords
    @credit_keywords ||= Keyword
      .joins(subcategory: :category)
      .where("categories.name ILIKE ?", "earnings")
      .pluck(:name)
      .select { |word| word.to_s.match?(/RECEBIMENTO|TRANSFERENCIA|LIBERACAO/i) }
      .map(&:upcase)
  end

  def debit_keywords
    @debit_keywords ||= Keyword
      .joins(subcategory: :category)
      .pluck(:name)
      .map(&:upcase)
  end
end
