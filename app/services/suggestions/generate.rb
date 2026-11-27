module Suggestions
  # Runs the suggestion pipeline for one SuggestionRun. Keyword rules have already run at import
  # time; this only looks at what they left uncategorized:
  #
  # 1. Merchants the owner already categorized get a "history" suggestion. No API call.
  # 2. The rest go to Claude, if a key is saved, in as few requests as possible (one per
  #    MAX_GROUPS_PER_REQUEST merchants; one per import in practice). The same request also
  #    returns keyword rule suggestions.
  # 3. Local rule suggestions (repeated corrections, overridden rules) always run.
  #
  # Suggestions are saved per batch, so a retry after a failure skips what was already done.
  # Retryable Claude errors are re-raised for the job to retry; others mark the run failed.
  class Generate
    MAX_GROUPS_PER_REQUEST = 150

    def self.call(run)
      new(run).call
    end

    def initialize(run)
      @run = run
    end

    def call
      run.update!(status: "running", started_at: run.started_at || Time.current, error_code: nil, error_message: nil)

      groups = Candidates.call(run.monthly_statement)
      rejected = Rejections.by_merchant(groups.map(&:merchant_key))
      remaining = suggest_from_history(groups)
      suggest_with_claude(remaining, rejected) if remaining.any? && setting.claude_configured?
      run.rule_suggestions_count += Rules::LocalSuggester.call(run: run).count { _1.suggestion_run_id == run.id }

      run.update!(status: "succeeded", finished_at: Time.current)
    rescue Ai::Client::RetryableError => e
      run.update!(status: "queued", error_code: e.code, error_message: e.message)
      raise
    rescue Ai::Client::Error => e
      fail_run(e.code, e.message)
    rescue StandardError => e
      Rails.logger.error("Suggestion run #{run.id} failed: #{e.class}: #{e.message}")
      fail_run("internal", "Something went wrong while generating suggestions.")
    end

    private

    attr_reader :run

    def setting
      @setting ||= AppSetting.current
    end

    # @return [Array<Candidates::Group>] groups history couldn't place
    def suggest_from_history(groups)
      matches = HistoryMatcher.call(groups)
      groups.select { matches.key?(_1.merchant_key) }.each do |group|
        match = matches.fetch(group.merchant_key)
        save(group, origin: "history", subcategory_id: match.subcategory_id, confidence: match.confidence, reason: match.reason)
        run.increment(:history_suggestions_count, group.transactions.size)
      end
      run.save!
      groups.reject { matches.key?(_1.merchant_key) }
    end

    def suggest_with_claude(groups, rejected)
      client = Ai::Client.for(setting)
      run.update!(model: client.model)
      suggester = Ai::Suggester.new(client)

      groups.each_slice(MAX_GROUPS_PER_REQUEST) do |batch|
        result = suggester.call(batch, rejected: rejected)
        result.suggestions.each do |suggestion|
          save(suggestion.group, origin: "ai", subcategory_id: suggestion.subcategory_id,
                                 confidence: suggestion.confidence, reason: suggestion.reason)
          run.ai_suggestions_count += suggestion.group.transactions.size
        end
        result.rule_suggestions.each { save_rule(_1) }
        run.ai_groups_sent += batch.size
        run.ai_requests_count += 1
        run.input_tokens += result.input_tokens
        run.output_tokens += result.output_tokens
        run.save!
      end
    end

    def save(group, origin:, subcategory_id:, confidence:, reason:)
      CategorySuggestion.transaction do
        group.transactions.each do |transaction|
          CategorySuggestion.create!(
            parsed_transaction: transaction, subcategory_id: subcategory_id, suggestion_run: run,
            origin: origin, confidence: confidence, reason: reason
          )
        end
      end
    end

    def save_rule(suggestion)
      change = Rules::Change.new(action: suggestion[:action], keyword: suggestion[:keyword_id] && Keyword.find_by(id: suggestion[:keyword_id]),
                                 name: suggestion[:keyword], subcategory_id: suggestion[:subcategory_id])
      saved = Rules::SuggestionWriter.call(change, origin: "ai", run: run, confidence: suggestion[:confidence], reason: suggestion[:reason])
      run.rule_suggestions_count += 1 if saved&.suggestion_run_id == run.id
    end

    def fail_run(code, message)
      run.update!(status: "failed", error_code: code, error_message: message, finished_at: Time.current)
    end
  end
end
