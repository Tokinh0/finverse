module Api::V1
  # GET /suggestions/summary: what the navigation badge needs.
  class SuggestionsController < ApplicationController
    def summary
      latest = SuggestionRun.order(:created_at).last
      categories = CategorySuggestion.pending.count
      rules = RuleSuggestion.pending.count
      render json: {
        pending_count: categories + rules,
        pending_category_count: categories,
        pending_rule_count: rules,
        claude_configured: AppSetting.current.claude_configured?,
        latest_run: latest && SuggestionRunPresenter.new(latest)
      }
    end
  end
end
