module Ai
  # Checks Claude's answer item by item. Anything malformed or pointing at an unknown item or
  # subcategory is dropped (and counted); one bad item never fails the whole batch.
  module ResponseValidator
    MAX_REASON_LENGTH = 200

    Result = Struct.new(:category_suggestions, :rule_suggestions, :dropped, keyword_init: true)

    module_function

    # @param data [Hash] parsed JSON from Claude
    # @param item_ids [Enumerable<Integer>] ids sent in this batch
    # @param subcategory_ids [Enumerable<Integer>] subcategories Claude may pick
    # @param excluded [Hash{Integer => Array<Integer>}] subcategories rejected per item id
    # @param keyword_ids [Enumerable<Integer>] existing rules Claude may update or delete
    def call(data, item_ids:, subcategory_ids:, excluded: {}, keyword_ids: [])
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

      raw_rules = data.is_a?(Hash) ? Array(data["rule_suggestions"]) : []
      rules = raw_rules.filter_map { rule_suggestion(_1, subcategory_ids, keyword_ids.to_set) }
      dropped += raw_rules.size - rules.size

      Result.new(category_suggestions: suggestions, rule_suggestions: rules, dropped: dropped)
    end

    def rule_suggestion(entry, subcategory_ids, keyword_ids)
      return unless entry.is_a?(Hash)

      action = entry["action"]
      keyword_id = integer(entry["keyword_id"])
      subcategory_id = integer(entry["subcategory_id"])
      keyword = entry["keyword"].to_s.strip
      confidence = entry["confidence"]
      return unless confidence.is_a?(Numeric) && confidence.between?(0, 1)

      valid =
        case action
        when "create" then keyword.present? && subcategory_ids.include?(subcategory_id)
        when "update" then keyword_ids.include?(keyword_id) && (keyword.present? || subcategory_ids.include?(subcategory_id)) &&
                           (subcategory_id.nil? || subcategory_ids.include?(subcategory_id))
        when "delete" then keyword_ids.include?(keyword_id)
        end
      return unless valid

      { action: action, keyword_id: action == "create" ? nil : keyword_id, keyword: keyword.presence,
        subcategory_id: action == "delete" ? nil : subcategory_id, confidence: confidence.to_f.round(2),
        reason: entry["reason"].to_s.strip.truncate(MAX_REASON_LENGTH).presence }
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
