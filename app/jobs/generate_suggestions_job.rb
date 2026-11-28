# Runs Suggestions::Generate in the background after an import (or on request).
# Rate limits, timeouts and outages are retried with backoff; after the last attempt the run is
# marked failed with the error's message so the UI can show it.
#
# Jobs have no request, so the run's own profile becomes Current.profile for the whole job.
class GenerateSuggestionsJob < ApplicationJob
  queue_as :default

  retry_on Ai::Client::RetryableError, wait: :polynomially_longer, attempts: 4 do |job, error|
    run = SuggestionRun.unscoped.find_by(id: job.arguments.first)
    Current.set(profile: run&.profile) do
      run&.update!(status: "failed", error_code: error.code, error_message: error.message, finished_at: Time.current)
    end
  end

  def perform(run_id)
    run = SuggestionRun.unscoped.includes(:profile).find_by(id: run_id)
    return unless run

    Current.set(profile: run.profile) { Suggestions::Generate.call(run) }
  end
end
