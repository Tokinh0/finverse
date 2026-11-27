module Ai
  # Checks Claude's answer item by item. Anything malformed or pointing at an unknown item or
  # subcategory is dropped (and counted); one bad item never fails the whole batch.
  module ResponseValidator
    MAX_REASON_LENGTH = 200

    Result = Struct.new(:category_suggestions, :dropped, keyword_init: true)

    module_function

    # @param data [Hash] parsed JSON from Claude
    # @param item_ids [Enumerable<Integer>] ids sent in this batch
    # @param subcategory_ids [Enumerable<Integer>] subcategories Claude may pick
    # @param excluded [Hash{Integer => Array<Integer>}] subcategories rejected per item id
    def call(data, item_ids:, subcategory_ids:, excluded: {})
      item_ids = item_ids.to_set
      subcategory_ids = subcategory_ids.to_set
      raw = data.is_a?(Hash) ? Array(data["category_suggestions"]) : []
      seen = Set.new
      dropped = 0

      suggestions = raw.filter_map do |entry|
        suggestion = category_suggestion(entry, item_ids, subcategory_ids, excluded)
        if suggestion.nil? || seen.include?(suggestion[:item_id])
          dropped += 1
          next
        end

        seen << suggestion[:item_id]
        suggestion
      end

      Result.new(category_suggestions: suggestions, dropped: dropped)
    end

    def category_suggestion(entry, item_ids, subcategory_ids, excluded)
      return unless entry.is_a?(Hash)

      item_id = integer(entry["item_id"])
      subcategory_id = integer(entry["subcategory_id"])
      confidence = entry["confidence"]
      return unless item_ids.include?(item_id) && subcategory_ids.include?(subcategory_id)
      return if excluded.fetch(item_id, []).include?(subcategory_id)
      return unless confidence.is_a?(Numeric) && confidence.between?(0, 1)

      { item_id: item_id, subcategory_id: subcategory_id, confidence: confidence.to_f.round(2),
        reason: entry["reason"].to_s.strip.truncate(MAX_REASON_LENGTH).presence }
    end

    def integer(value)
      value if value.is_a?(Integer)
    end
  end
end
