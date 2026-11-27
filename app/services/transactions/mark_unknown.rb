module Transactions
  # "No idea": the owner can't remember what an uncategorized transaction is.
  #
  # It has no effect on categorization: the transaction stays in the Outros fallback (still
  # "uncategorized" in reports), nothing is rejected, and nothing about it is sent to Claude.
  # It only records the mark, dismisses its pending suggestion and keeps it out of future
  # suggestion runs and rule re-application. Categorizing it by hand, or `undo`, clears the mark.
  module MarkUnknown
    Result = Struct.new(:success?, :transaction, :errors, keyword_init: true)

    module_function

    def call(transaction)
      unless transaction.categorized_by_uncategorized?
        return Result.new(success?: false, transaction: transaction, errors: [ I18n.t("transactions.only_uncategorized_can_be_marked") ])
      end

      Transaction.transaction do
        transaction.update!(unknown_marked_at: transaction.unknown_marked_at || Time.current)
        CategorySuggestion.pending.where(parsed_transaction: transaction)
                          .update_all(status: "dismissed", decided_at: Time.current, updated_at: Time.current)
      end
      Result.new(success?: true, transaction: transaction, errors: [])
    end

    # Takes the mark away; the next suggestion run may suggest for it again.
    def undo(transaction)
      transaction.update!(unknown_marked_at: nil)
      Result.new(success?: true, transaction: transaction, errors: [])
    end
  end
end
