module Rules
  # Saves a proposed rule change as a pending RuleSuggestion, unless it is pointless or
  # unwanted: the same change is already pending, a new rule would match no transaction, it would
  # match too much, or the owner rejected it and the data hasn't changed enough since.
  module SuggestionWriter
    # A new keyword matching more than this share of all transactions is too broad.
    MAX_MATCH_SHARE = 0.25
    MIN_KEYWORD_LENGTH = 3

    module_function

    # @return [RuleSuggestion, nil]
    def call(change, origin:, confidence:, reason:, run: nil)
      return if change.action != "delete" && change.parsed_name.delete("_").length < MIN_KEYWORD_LENGTH
      return if change.action == "create" &&
                Keyword.exists?(parsed_name: change.parsed_name, subcategory_id: change.subcategory_id, **change.amounts)
      return if change.no_op?

      existing = RuleSuggestion.pending.find_by(fingerprint: change.fingerprint)
      return existing if existing

      matched = Preview.call(change, limit: 0).matched
      return if matched.zero? && change.action == "create"
      return if too_broad?(change)
      return if Rejections.suppressed?(change.fingerprint, matched)

      RuleSuggestion.create!(
        action: change.action, keyword: change.keyword, name: change.name, subcategory_id: change.subcategory_id,
        min_amount: change.min_amount, max_amount: change.max_amount, origin: origin, confidence: confidence, reason: reason, suggestion_run: run
      )
    end

    def too_broad?(change)
      return false if change.action == "delete"

      total = Transaction.count
      matching = Transaction.where("parsed_name LIKE ?", "%#{Transaction.sanitize_sql_like(change.parsed_name)}%").count
      total.positive? && matching > [ total * MAX_MATCH_SHARE, 10 ].max
    end
  end
end
