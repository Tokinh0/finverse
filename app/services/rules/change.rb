module Rules
  # A change to the keyword rules, used both to preview it and to apply it.
  #
  # - create: a new keyword `name` → `subcategory_id`.
  # - update: `keyword` gets a new `name` and/or `subcategory_id`.
  # - delete: `keyword` is removed.
  class Change
    attr_reader :action, :keyword, :name, :subcategory_id

    def initialize(action:, keyword: nil, name: nil, subcategory_id: nil)
      @action = action.to_s
      @keyword = keyword
      @name = name.presence || keyword&.name
      @subcategory_id = (subcategory_id.presence || keyword&.subcategory_id)&.to_i
    end

    def parsed_name
      StringUtils.default_string_parse(name.to_s)
    end

    def fingerprint
      case action
      when "create" then [ action, parsed_name, subcategory_id ]
      when "update" then [ action, keyword&.id, parsed_name, subcategory_id ]
      else [ action, keyword&.id ]
      end.join("|")
    end

    # The rule list as it would be after the change, in matcher order (new rules last).
    # @param keywords [Array<Keyword>] the current rules
    def keywords_after(keywords)
      case action
      when "create" then keywords + [ Keyword.new(name: name, subcategory_id: subcategory_id) ]
      when "update"
        keywords.map do |kw|
          kw.id == keyword.id ? kw.dup.tap { _1.assign_attributes(id: kw.id, name: name, subcategory_id: subcategory_id) } : kw
        end
      else keywords.reject { _1.id == keyword.id }
      end
    end

    # Transactions whose best match could change: those the keyword categorizes today, and
    # those whose name contains (or is contained in) the old or new keyword text.
    def candidates
      texts = [ parsed_name, keyword&.parsed_name ].compact.uniq.reject(&:blank?)
      conditions = texts.map do |text|
        Transaction.sanitize_sql([ "transactions.parsed_name LIKE :like OR :text LIKE '%' || transactions.parsed_name || '%'",
                                   { like: "%#{Transaction.sanitize_sql_like(text)}%", text: text } ])
      end
      conditions << Transaction.sanitize_sql([ "transactions.keyword_id = ?", keyword.id ]) if keyword
      return Transaction.none if conditions.empty?

      Transaction.where(conditions.map { "(#{_1})" }.join(" OR "))
    end
  end
end
