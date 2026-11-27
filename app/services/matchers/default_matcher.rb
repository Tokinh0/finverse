module Matchers
  class DefaultMatcher
    class << self
      def compare(input, keyword)
        parsed_name = StringUtils.default_string_parse(input)
        parsed_keyword = StringUtils.default_string_parse(keyword)
        match_score(parsed_name, parsed_keyword)
      end

      # @param keywords [Enumerable<Keyword>] pass a preloaded list when matching many names
      # @param amount [Numeric, nil] the transaction amount; rules with an amount range only apply
      #   when it's inside the range (and never when it's nil)
      # On equal scores a rule with an amount range beats one without (it's more specific);
      # otherwise the first rule in the list wins.
      def find_best_keyword_match(word, keywords = Keyword.all, amount: nil)
        parsed_name = StringUtils.default_string_parse(word)
        keywords.select { |kw| applies_to_amount?(kw, amount) }
                .map { |kw| [ kw, match_score(parsed_name, kw.parsed_name) ] }
                .select { |_, score| score.positive? }
                .max_by { |kw, score| [ score, ranged?(kw) ? 1 : 0 ] }
                &.first
      end

      def applies_to_amount?(keyword, amount)
        !keyword.respond_to?(:applies_to_amount?) || keyword.applies_to_amount?(amount)
      end

      def ranged?(keyword)
        keyword.respond_to?(:amount_range?) && keyword.amount_range?
      end

      def match_score(input, keyword)
        return 4 if input == keyword                     # Exact match
        return 3 if input.include?(" #{keyword} ")       # Whole word match
        return 2 if input.include?(keyword)              # Partial match
        return 1 if keyword.include?(input)              # Partial match
        0
      end
    end
  end
end
