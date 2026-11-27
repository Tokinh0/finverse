class SuggestionRunPresenter
  def initialize(run)
    @run = run
  end

  def as_json(*)
    @run.slice(
      :id, :monthly_statement_id, :status, :error_code, :error_message, :model,
      :history_suggestions_count, :ai_suggestions_count, :ai_requests_count, :input_tokens, :output_tokens,
      :started_at, :finished_at, :created_at
    )
  end
end
