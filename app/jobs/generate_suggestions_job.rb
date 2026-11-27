# Runs Suggestions::Generate in the background after an import (or on request).
# Rate limits, timeouts and outages are retried with backoff; after the last attempt the run is
# marked failed with the error's message so the UI can show it.
class GenerateSuggestionsJob < ApplicationJob
  queue_as :default

  retry_on Ai::Client::RetryableError, wait: :polynomially_longer, attempts: 4 do |job, error|
    SuggestionRun.find_by(id: job.arguments.first)&.update!(
      status: "failed", error_code: error.code, error_message: error.message, finished_at: Time.current
    )
  end

  def perform(run_id)
    run = SuggestionRun.find_by(id: run_id)
    Suggestions::Generate.call(run) if run
  end
end
