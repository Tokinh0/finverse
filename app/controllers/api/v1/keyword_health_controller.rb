module Api::V1
  # GET /keywords/health: per rule, how often it matches and how often the owner overrides it,
  # with flags and any pending suggestion that would fix it.
  class KeywordHealthController < ApplicationController
    def index
      pending = RuleSuggestion.pending.where.not(keyword_id: nil).group_by(&:keyword_id)
      render json: Rules::Health.call.values.map { |entry|
        {
          keyword_id: entry.keyword.id,
          matches: entry.matches,
          overrides: entry.overrides,
          top_override_subcategory_id: entry.top_override_subcategory_id,
          overlapping_keyword_ids: entry.overlapping_keyword_ids,
          flags: entry.flags,
          pending_suggestion_ids: pending.fetch(entry.keyword.id, []).map(&:id)
        }
      }
    end
  end
end
