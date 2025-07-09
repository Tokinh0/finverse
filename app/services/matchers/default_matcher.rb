module Matchers
  class DefaultMatcher
    include StringUtils

    class << self
      def compare(input, keyword)
        parsed_name = default_string_parse(input)
        parsed_keyword = default_string_parse(keyword)
        match_score(parsed_name, parsed_keyword)
      end

      def find_best_keyword_match(word)
        parsed_name = default_string_parse(word)
        Keyword.all.map { |kw| [kw, match_score(parsed_name, kw.parsed_name)] }.select { |_, score| score > 0 }.max_by { |_, score| score }&.first
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