module Rules
  # Rejection memory for rule suggestions: a rejected change is proposed again only when it
  # would now match clearly more transactions than when the owner said no (at least 50% more
  # and at least 5 more).
  module Rejections
    GROWTH_FACTOR = 1.5
    MIN_GROWTH = 5
    RECENT_FOR_CONTEXT = 20

    module_function

    def suppressed?(fingerprint, match_count)
      previous = RuleSuggestion.rejected.where(fingerprint: fingerprint).maximum(:match_count_at_decision)
      return false if previous.nil?

      match_count < [ (previous * GROWTH_FACTOR).ceil, previous + MIN_GROWTH ].max
    end

    # Recent rejections, as context for Claude: [action, keyword, subcategory id].
    def recent
      RuleSuggestion.rejected.order(decided_at: :desc).limit(RECENT_FOR_CONTEXT).map do |suggestion|
        [ suggestion.action, suggestion.parsed_name || suggestion.keyword&.parsed_name, suggestion.subcategory_id ].compact
      end
    end
  end
end
