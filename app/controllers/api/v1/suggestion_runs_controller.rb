module Api::V1
  class SuggestionRunsController < ApplicationController
    def index
      render json: SuggestionRun.order(created_at: :desc).limit(10).map { SuggestionRunPresenter.new(_1) }
    end

    # Suggest for every uncategorized transaction ("Suggest again").
    def create
      run = Suggestions::Enqueue.call
      if run
        render json: SuggestionRunPresenter.new(run), status: :created
      else
        render json: { errors: [ "Nothing to suggest, or suggestions are already being generated" ] }, status: :unprocessable_content
      end
    end
  end
end
