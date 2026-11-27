module Rules
  # Rule suggestions the app makes on its own, without Claude:
  #
  # - Repeated corrections: the owner put the same merchant in the same subcategory at least
  #   NUDGE_THRESHOLD times and no rule does it → create a rule for the merchant.
  # - Overridden rules: a rule flagged "overridden" whose overrides mostly (DOMINANT_SHARE) go
  #   to one subcategory → move the rule to that subcategory.
  module LocalSuggester
    NUDGE_THRESHOLD = 3
    DOMINANT_SHARE = 0.7
    OWNER_SOURCES = %w[manual ai_accepted].freeze

    module_function

    # @param merchant_keys [Enumerable<String>, nil] limit the correction check to these merchants
    # @return [Array<RuleSuggestion>] pending suggestions (new or already pending)
    def call(merchant_keys: nil, run: nil)
      (repeated_corrections(merchant_keys, run) + overridden_rules(run)).compact.uniq
    end

    # The suggestion to show right after the owner moved a transaction by hand, if any.
    # @return [RuleSuggestion, nil]
    def nudge_for(transaction)
      repeated_corrections([ Transactions::Merchant.key(transaction) ], nil).compact.first
    end

    def repeated_corrections(merchant_keys, run)
      events = CategorizationEvent.where(to_source: OWNER_SOURCES).where.not(to_subcategory_id: nil)
      events = events.where(merchant_key: merchant_keys.to_a) if merchant_keys
      keywords = Keyword.all.to_a
      names = Subcategory.includes(:category).index_by(&:id)

      events.group(:merchant_key, :to_subcategory_id).having("COUNT(*) >= ?", NUDGE_THRESHOLD).count.map do |(key, subcategory_id), count|
        next if Matchers::DefaultMatcher.find_best_keyword_match(key, keywords)&.subcategory_id == subcategory_id

        label = names[subcategory_id] && "#{names[subcategory_id].category.name} / #{names[subcategory_id].name}"
        SuggestionWriter.call(
          Change.new(action: "create", name: key.tr("_", " "), subcategory_id: subcategory_id),
          origin: "local", run: run, confidence: [ 0.6 + (0.1 * count), 0.95 ].min.round(2),
          reason: "You moved #{count} transactions from this merchant to #{label} by hand"
        )
      end
    end

    def overridden_rules(run)
      Health.call.values.select { _1.flags.include?("overridden") }.map do |entry|
        next unless entry.top_override_subcategory_id && entry.top_override_count >= DOMINANT_SHARE * entry.overrides

        target = Subcategory.find_by(id: entry.top_override_subcategory_id)
        next unless target

        SuggestionWriter.call(
          Change.new(action: "update", keyword: entry.keyword, subcategory_id: target.id),
          origin: "local", run: run, confidence: 0.75,
          reason: "You moved #{entry.top_override_count} of this rule's transactions to #{target.category.name} / #{target.name}"
        )
      end
    end
  end
end
