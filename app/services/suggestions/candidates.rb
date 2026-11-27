module Suggestions
  # Uncategorized transactions that have no pending suggestion yet, grouped by merchant
  # (`Transactions::Merchant.key`). Every suggestion is made per group and then applied to each
  # transaction in it, so a merchant seen five times costs one decision, not five.
  module Candidates
    Group = Struct.new(:merchant_key, :transactions, keyword_init: true) do
      def sample_name
        transactions.first.name
      end

      def transaction_type
        transactions.map(&:transaction_type).tally.max_by(&:last).first
      end

      def average_amount
        (transactions.sum(&:amount) / transactions.size).to_f.round(2)
      end

      def statement_kinds
        transactions.map { _1.monthly_statement.statement_kind }.compact.uniq
      end
    end

    module_function

    # @param monthly_statement [MonthlyStatement, nil] limit to one statement; nil = everything
    # @return [Array<Group>] biggest groups first
    def call(monthly_statement = nil)
      scope = Transaction.categorized_by_uncategorized
                         .where.missing(:pending_category_suggestion)
                         .includes(:monthly_statement)
                         .order(:transaction_date, :id)
      scope = scope.where(monthly_statement: monthly_statement) if monthly_statement

      scope.group_by { Transactions::Merchant.key(_1) }
           .reject { |key, _| key.blank? }
           .map { |key, transactions| Group.new(merchant_key: key, transactions: transactions) }
           .sort_by { -_1.transactions.size }
    end
  end
end
