module Suggestions
  # The owner's answer to a category suggestion.
  #
  # - accept: the transaction moves to the suggested subcategory (source "ai_accepted").
  # - accept with another subcategory ("change"): the transaction moves there (source "manual")
  #   and the suggestion counts as rejected, so it isn't proposed for this merchant again.
  # - reject: nothing moves; the rejection is remembered.
  # - dont_know: nothing moves and nothing is remembered about the subcategory; the transaction
  #   is marked "no idea" (Transactions::MarkUnknown).
  #
  # Both go through Transactions::Recategorize, which records the CategorizationEvent.
  module Decide
    Result = Struct.new(:success?, :suggestion, :errors, keyword_init: true)

    module_function

    def accept(suggestion, subcategory_id: nil)
      return stale(suggestion) unless suggestion.pending?
      return supersede(suggestion) unless suggestion.parsed_transaction.categorized_by_uncategorized?

      chosen = subcategory_id.presence&.to_i || suggestion.subcategory_id
      as_suggested = chosen == suggestion.subcategory_id

      errors = []
      CategorySuggestion.transaction do
        suggestion.update!(status: as_suggested ? "accepted" : "rejected", decided_at: Time.current)
        result = Transactions::Recategorize.call(
          suggestion.parsed_transaction, subcategory_id: chosen, source: as_suggested ? "ai_accepted" : "manual"
        )
        errors = result.errors
        raise ActiveRecord::Rollback unless result.success?
      end
      return Result.new(success?: true, suggestion: suggestion, errors: []) if errors.empty?

      Result.new(success?: false, suggestion: suggestion.reload, errors: errors)
    end

    # "No idea": the transaction stays where it is and gets no more suggestions. Not a rejection.
    def dont_know(suggestion)
      return stale(suggestion) unless suggestion.pending?

      result = Transactions::MarkUnknown.call(suggestion.parsed_transaction)
      Result.new(success?: result.success?, suggestion: suggestion.reload, errors: result.errors)
    end

    def reject(suggestion)
      return stale(suggestion) unless suggestion.pending?

      suggestion.update!(status: "rejected", decided_at: Time.current)
      Result.new(success?: true, suggestion: suggestion, errors: [])
    end

    # Accepts every pending suggestion at or above `min_confidence` and/or for one merchant.
    # @return [Integer] how many were accepted
    def bulk_accept(min_confidence: nil, merchant_key: nil)
      raise ArgumentError, "Give min_confidence or merchant_key" if min_confidence.blank? && merchant_key.blank?

      scope = CategorySuggestion.pending.includes(:parsed_transaction)
      scope = scope.where(confidence: min_confidence.to_d..) if min_confidence.present?
      scope.to_a
           .select { merchant_key.blank? || Transactions::Merchant.key(_1.parsed_transaction) == merchant_key }
           .count { accept(_1).success? }
    end

    def stale(suggestion)
      Result.new(success?: false, suggestion: suggestion, errors: [ "This suggestion was already #{suggestion.status}" ])
    end

    def supersede(suggestion)
      suggestion.update!(status: "superseded", decided_at: Time.current)
      Result.new(success?: false, suggestion: suggestion, errors: [ "The transaction was already categorized" ])
    end
  end
end
