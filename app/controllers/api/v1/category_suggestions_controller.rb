module Api::V1
  class CategorySuggestionsController < ApplicationController
    MAX_RESULTS = 500

    # GET /category_suggestions?status=pending&month=YYYY-MM&min_confidence=0.8
    def index
      scope = CategorySuggestion.where(status: params[:status].presence || "pending")
                                .includes(subcategory: :category, parsed_transaction: { subcategory: :category })
                                .order(confidence: :desc, id: :asc)
                                .limit(MAX_RESULTS)
      scope = scope.where(confidence: params[:min_confidence].to_d..) if params[:min_confidence].present?
      if (month = parse_month)
        scope = scope.joins(:parsed_transaction).where(transactions: { transaction_date: month.all_month })
      end

      render json: scope.map { CategorySuggestionPresenter.new(_1) }
    end

    # Body: { subcategory_id } to accept with another subcategory.
    def accept
      render_decision Suggestions::Decide.accept(suggestion, subcategory_id: params[:subcategory_id])
    end

    def reject
      render_decision Suggestions::Decide.reject(suggestion)
    end

    # "No idea": the transaction stays in Outros and gets no more suggestions.
    def dont_know
      render_decision Suggestions::Decide.dont_know(suggestion)
    end

    # Body: { min_confidence } and/or { merchant_key }
    def bulk_accept
      count = Suggestions::Decide.bulk_accept(min_confidence: params[:min_confidence], merchant_key: params[:merchant_key])
      render json: { accepted_count: count }
    rescue ArgumentError => e
      render json: { errors: [ e.message ] }, status: :unprocessable_content
    end

    private

    def suggestion
      CategorySuggestion.find(params[:id])
    end

    def parse_month
      Date.strptime(params[:month].to_s, "%Y-%m") if params[:month].present?
    rescue Date::Error
      nil
    end

    def render_decision(result)
      if result.success?
        render json: CategorySuggestionPresenter.new(result.suggestion.reload)
      else
        render json: { errors: result.errors }, status: :unprocessable_content
      end
    end
  end
end
