module Api::V1
  class RuleSuggestionsController < ApplicationController
    # GET /rule_suggestions?status=pending
    def index
      suggestions = RuleSuggestion.where(status: params[:status].presence || "pending")
                                  .includes(:keyword).order(confidence: :desc, id: :asc).limit(100)
      render json: suggestions.map { present(_1) }
    end

    # Body: { name, subcategory_id } to edit before accepting; reapply: none | uncategorized | all
    def accept
      result = Rules::Decide.accept(suggestion, name: params[:name], subcategory_id: params[:subcategory_id],
                                                reapply: params[:reapply].presence || "uncategorized")
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
