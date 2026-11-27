module Api::V1
  class TransactionsController < ApplicationController
    def index
      result = Transactions::Search.call(params.permit(:month, :category_id, :subcategory_id, :transaction_type, :q, :page, :per_page))

      render json: {
        transactions: result.transactions.map { |t| TransactionPresenter.new(t) },
        meta: {
          total_count: result.total_count,
          total_amount: result.total_amount,
          page: result.page,
          per_page: result.per_page,
          months: result.months
        }
      }
    end

    # Body: { transaction: { subcategory_id, transaction_type, keyword, apply_to_matching } }
    def update
      result = Transactions::Recategorize.call(Transaction.find(params[:id]), **recategorize_params)

      if result.success?
        nudge = Rules::LocalSuggester.nudge_for(result.transaction) if result.transaction.categorized_by_manual? && !result.keyword
        render json: {
          transaction: TransactionPresenter.new(result.transaction.reload),
          keyword: result.keyword && KeywordPresenter.new(result.keyword),
          updated_count: result.updated_count,
          rule_nudge: nudge && RuleSuggestionPresenter.new(nudge, subcategories: Subcategory.includes(:category).index_by(&:id))
        }
      else
        render json: { errors: result.errors }, status: :unprocessable_content
      end
    end

    private

    def recategorize_params
      params.require(:transaction)
            .permit(:subcategory_id, :transaction_type, :keyword, :apply_to_matching)
            .to_h
            .symbolize_keys
    end
  end
end
