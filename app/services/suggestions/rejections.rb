module Suggestions
  # What the owner said no to: rejected category suggestions, by merchant. Used so neither the
  # history matcher nor Claude proposes the same subcategory for that merchant again.
  module Rejections
    module_function

    # @param keys [Enumerable<String>] merchant keys to look up
    # @return [Hash{String => Array<Integer>}] rejected subcategory ids per merchant key
    def by_merchant(keys)
      keys = keys.to_set
      CategorySuggestion.rejected.includes(:parsed_transaction).each_with_object(Hash.new { |h, k| h[k] = [] }) do |suggestion, result|
        key = Transactions::Merchant.key(suggestion.parsed_transaction)
        result[key] |= [ suggestion.subcategory_id ] if keys.include?(key)
      end
    end
  end
end
