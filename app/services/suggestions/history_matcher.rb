module Suggestions
  # Suggests a subcategory for a merchant the owner has already categorized by hand (or by
  # accepting a suggestion), without calling Claude. Subcategories the owner rejected for that
  # merchant are never suggested again.
  #
  # Confidence grows with how many times the owner picked the subcategory and how consistently:
  # 1 of 1 → 0.70, 2 of 2 → 0.80, 3+ of 3+ → 0.90; disagreement scales it down.
  module HistoryMatcher
    CONFIRMED_SOURCES = %w[manual ai_accepted].freeze
    MIN_CONFIDENCE = 0.5

    Match = Struct.new(:subcategory_id, :confidence, :reason, keyword_init: true)

    module_function

    # @param groups [Array<Candidates::Group>]
    # @return [Hash{String => Match}] by merchant key
    def call(groups)
      keys = groups.map(&:merchant_key).to_set
      return {} if keys.empty?

      picks = confirmed_picks(keys)
      notes = latest_notes(keys)
      rejected = Rejections.by_merchant(keys)
      names = Subcategory.includes(:category).index_by(&:id)

      picks.each_with_object({}) do |(key, subcategory_ids), matches|
        counts = subcategory_ids.tally.except(*rejected.fetch(key, []))
        next if counts.empty?

        subcategory_id, count = counts.max_by(&:last)
        confidence = ([ 0.6 + (0.1 * count), 0.9 ].min * count / subcategory_ids.size).round(2)
        next if confidence < MIN_CONFIDENCE

        label = names[subcategory_id] && "#{names[subcategory_id].category.name} / #{names[subcategory_id].name}"
        reason = "You put #{count} #{'transaction'.pluralize(count)} from this merchant in #{label}"
        note = notes[[ key, subcategory_id ]]
        reason += " (your note: \"#{note}\")" if note
        matches[key] = Match.new(subcategory_id: subcategory_id, confidence: confidence, reason: reason.truncate(250))
      end
    end

    # @return [Hash{Array(String, Integer) => String}] latest note per merchant and subcategory
    def latest_notes(keys)
      CategorizationEvent.with_notes.where(merchant_key: keys.to_a).order(:created_at)
                         .each_with_object({}) { |event, notes| notes[[ event.merchant_key, event.to_subcategory_id ]] = event.note }
    end

    # @return [Hash{String => Array<Integer>}] subcategory ids the owner chose, per merchant key
    def confirmed_picks(keys)
      Transaction.where(categorization_source: CONFIRMED_SOURCES)
                 .select(:id, :name, :parsed_name, :subcategory_id)
                 .each_with_object(Hash.new { |h, k| h[k] = [] }) do |transaction, picks|
        key = Transactions::Merchant.key(transaction)
        picks[key] << transaction.subcategory_id if keys.include?(key)
      end
    end
  end
end
