module Rules
  # The owner's answer to a rule suggestion. Accepting may edit the rule first ("edit then
  # accept") and chooses what to re-apply it to (see Rules::Apply).
  module Decide
    Result = Struct.new(:success?, :suggestion, :keyword, :updated_count, :errors, keyword_init: true)

    module_function

    # `amounts:` (optional) replaces the suggested amount range: { min_amount:, max_amount: }, nil = no bound.
    def accept(suggestion, name: nil, subcategory_id: nil, reapply: "uncategorized", amounts: nil)
      return stale(suggestion) unless suggestion.pending?

      range = amounts || { min_amount: suggestion.min_amount, max_amount: suggestion.max_amount }
      change = Change.new(action: suggestion.action, keyword: suggestion.keyword,
                          name: name.presence || suggestion.name, subcategory_id: subcategory_id.presence || suggestion.subcategory_id,
                          **range)
      RuleSuggestion.transaction do
        moved = Preview.call(change, limit: 0).matched
        applied = Apply.call(change, reapply: reapply)
        suggestion.update!(status: "accepted", decided_at: Time.current, match_count_at_decision: moved)
        RuleSuggestion.pending.where(fingerprint: suggestion.fingerprint).update_all(status: "superseded", decided_at: Time.current)
        Result.new(success?: true, suggestion: suggestion, keyword: applied.keyword, updated_count: applied.updated_count, errors: [])
      end
    rescue ActiveRecord::RecordInvalid, ArgumentError, TypeError => e
      errors = e.respond_to?(:record) ? e.record.errors.full_messages : [ e.message ]
      Result.new(success?: false, suggestion: suggestion.reload, errors: errors, updated_count: 0)
    end

    def reject(suggestion)
      return stale(suggestion) unless suggestion.pending?

      moved = Preview.call(suggestion.change, limit: 0).matched
      suggestion.update!(status: "rejected", decided_at: Time.current, match_count_at_decision: moved)
      Result.new(success?: true, suggestion: suggestion, updated_count: 0, errors: [])
    end

    def stale(suggestion)
      Result.new(success?: false, suggestion: suggestion, updated_count: 0,
                 errors: [ I18n.t("suggestions.already_decided", status: I18n.t("suggestions.statuses.#{suggestion.status}")) ])
    end
  end
end
