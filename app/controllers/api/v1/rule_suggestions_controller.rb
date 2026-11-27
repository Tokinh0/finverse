module Api::V1
  class RuleSuggestionsController < ApplicationController
    # GET /rule_suggestions?status=pending
    def index
      suggestions = RuleSuggestion.where(status: params[:status].presence || "pending")
                                  .includes(:keyword).order(confidence: :desc, id: :asc).limit(100)
      render json: suggestions.map { present(_1) }
    end

    # Body: { name, subcategory_id, min_amount, max_amount } to edit before accepting (send both
    # amount keys to change the range; null = no bound); reapply: none | uncategorized | all
    def accept
      amounts = params.key?(:min_amount) || params.key?(:max_amount) ? { min_amount: params[:min_amount], max_amount: params[:max_amount] } : nil
      result = Rules::Decide.accept(suggestion, name: params[:name], subcategory_id: params[:subcategory_id],
                                                reapply: params[:reapply].presence || "uncategorized", amounts: amounts)
      render_decision(result)
    end

    def reject
      render_decision Rules::Decide.reject(suggestion)
    end

    private

    def suggestion
      @suggestion ||= RuleSuggestion.find(params[:id])
    end

    def subcategories
      @subcategories ||= Subcategory.includes(:category).index_by(&:id)
    end

    def present(suggestion)
      RuleSuggestionPresenter.new(suggestion, subcategories: subcategories)
    end

    def render_decision(result)
      if result.success?
        render json: {
          suggestion: present(result.suggestion.reload),
          keyword: result.keyword && KeywordPresenter.new(result.keyword),
          updated_count: result.updated_count
        }
      else
        render json: { errors: result.errors }, status: :unprocessable_content
      end
    end
  end
end
