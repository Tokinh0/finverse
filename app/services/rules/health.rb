module Rules
  # How well each keyword rule is doing, from the categorization history:
  #
  # - matches: transactions it categorizes now.
  # - overrides: times the owner moved one of its transactions elsewhere.
  # - flags: "overridden" (overrides ≥ OVERRIDE_MIN and ≥ OVERRIDE_RATE of its matches + overrides),
  #   "unused" (it categorizes nothing and was never overridden),
  #   "overlapping" (it ties with a rule for another subcategory on some transaction).
  module Health
    OVERRIDE_MIN = 3
    OVERRIDE_RATE = 0.5

    Entry = Struct.new(:keyword, :matches, :overrides, :top_override_subcategory_id, :top_override_count,
                       :overlapping_keyword_ids, :flags, keyword_init: true)

    module_function

    # @return [Hash{Integer => Entry}] by keyword id
    def call
      keywords = Keyword.includes(subcategory: :category).to_a
      matches = Transaction.where.not(keyword_id: nil).group(:keyword_id).count
      overrides = CategorizationEvent.overriding_keywords.group(:overridden_keyword_id, :to_subcategory_id).count
      overlaps = overlaps(keywords)

      keywords.to_h do |keyword|
        by_target = overrides.select { |(kw, _), _| kw == keyword.id }.transform_keys(&:last)
        override_count = by_target.values.sum
        top_target, top_count = by_target.max_by(&:last)
        match_count = matches.fetch(keyword.id, 0)

        flags = []
        flags << "overridden" if override_count >= OVERRIDE_MIN && override_count >= OVERRIDE_RATE * (match_count + override_count)
        flags << "unused" if match_count.zero? && override_count.zero?
        flags << "overlapping" if overlaps[keyword.id].present?

        [ keyword.id, Entry.new(keyword: keyword, matches: match_count, overrides: override_count,
                                top_override_subcategory_id: top_target, top_override_count: top_count.to_i,
                                overlapping_keyword_ids: overlaps.fetch(keyword.id, []), flags: flags) ]
      end
    end

    # Rules that tie for the best score on the same transaction but point at different
    # subcategories: which one wins depends on rule order, not on the data.
    def overlaps(keywords)
      result = Hash.new { |h, k| h[k] = [] }
      Transaction.select(:id, :parsed_name).find_each do |transaction|
        scored = keywords.map { [ _1, Matchers::DefaultMatcher.match_score(transaction.parsed_name.to_s, _1.parsed_name) ] }
                         .select { _2.positive? }
        next if scored.size < 2

        best = scored.map(&:last).max
        tied = scored.select { _2 == best }.map(&:first)
        next if tied.map(&:subcategory_id).uniq.size < 2

        tied.each { |kw| result[kw.id] |= (tied.map(&:id) - [ kw.id ]) }
      end
      result
    end
  end
end
