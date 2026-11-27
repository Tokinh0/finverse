module Keywords
  # Infers whether a transaction/keyword name is a debit, credit or ignored entry by
  # comparing it against the keyword lists from the seed data file
  # (`debit_keywords`, `credit_keywords`, `ignored_keywords`).
  class TypeInference
    LISTS = { debit: "debit_keywords", credit: "credit_keywords", ignored: "ignored_keywords" }.freeze

    class << self
      def call(parsed_name)
        scores = LISTS.keys.index_with do |type|
          keywords_for(type).map { |word| Matchers::DefaultMatcher.compare(word, parsed_name) }.max || 0
        end

        # Ties (including "no match at all") resolve in LISTS order, so an unmatched name is a debit.
        scores.max_by { |type, score| [ score, -LISTS.keys.index(type) ] }.first
      end

      def keywords_for(type)
        @keywords ||= {}
        @keywords[type] ||= (seed_data[LISTS.fetch(type)] || []).map { |k| StringUtils.default_string_parse(k) }
      end

      def reset!
        @keywords = nil
        @seed_data = nil
      end

      private

      def seed_data
        @seed_data ||= JsonUtils.load_initial_data
      end
    end
  end
end
