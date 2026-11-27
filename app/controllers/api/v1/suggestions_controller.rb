module Api::V1
  # GET /suggestions/summary: what the navigation badge needs.
  class SuggestionsController < ApplicationController
    def summary
      latest = SuggestionRun.order(:created_at).last
      render json: {
        pending_count: CategorySuggestion.pending.count,
        pending_category_count: CategorySuggestion.pending.count,
        claude_configured: AppSetting.current.claude_configured?,
        latest_run: latest && SuggestionRunPresenter.new(latest)
      }
    end
  end
end
