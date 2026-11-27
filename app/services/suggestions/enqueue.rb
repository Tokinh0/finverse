module Suggestions
  # Starts a suggestion run in the background when there is something to suggest for.
  # Runs even without a Claude key: history suggestions are local.
  module Enqueue
    module_function

    # @param monthly_statement [MonthlyStatement, nil] nil = every uncategorized transaction
    # @return [SuggestionRun, nil] nil when nothing is uncategorized or a run is already going
    def call(monthly_statement = nil)
      scope = Transaction.categorized_by_uncategorized.not_marked_unknown
      scope = scope.where(monthly_statement: monthly_statement) if monthly_statement
      return unless scope.exists?
      return if SuggestionRun.in_progress.exists?(monthly_statement: monthly_statement)

      SuggestionRun.create!(monthly_statement: monthly_statement).tap { GenerateSuggestionsJob.perform_later(_1.id) }
    end
  end
end
