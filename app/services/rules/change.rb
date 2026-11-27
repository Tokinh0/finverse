module Rules
  # A change to the keyword rules, used both to preview it and to apply it.
  #
  # - create: a new keyword `name` → `subcategory_id`, optionally only for amounts in
  #   `min_amount`..`max_amount`.
  # - update: `keyword` gets a new `name`, `subcategory_id` and/or amount range.
  # - delete: `keyword` is removed.
  #
  # For an update, a blank name or subcategory keeps the rule's current one, and an amount bound
  # left as KEEP keeps the current bound (nil removes it).
  class Change
    KEEP = Object.new.freeze

    attr_reader :action, :keyword, :name, :subcategory_id, :min_amount, :max_amount

    def initialize(action:, keyword: nil, name: nil, subcategory_id: nil, min_amount: KEEP, max_amount: KEEP)
      @action = action.to_s
      @keyword = keyword
      @name = name.presence || keyword&.name
      @subcategory_id = (subcategory_id.presence || keyword&.subcategory_id)&.to_i
      @min_amount = amount(min_amount, keyword&.min_amount)
      @max_amount = amount(max_amount, keyword&.max_amount)
    end

    def amount_range?
      !min_amount.nil? || !max_amount.nil?
    end

    def parsed_name
      StringUtils.default_string_parse(name.to_s)
    end

    # Rules without an amount range keep the fingerprint format they had before ranges existed,
    # so the rejection memory of older suggestions still applies.
    def fingerprint
      range = amount_range? ? [ min_amount&.to_s("F"), max_amount&.to_s("F") ] : []
      case action
      when "create" then [ action, parsed_name, subcategory_id, *range ]
      when "update" then [ action, keyword&.id, parsed_name, subcategory_id, *range ]
      else [ action, keyword&.id ]
      end.join("|")
    end

    # The rule list as it would be after the change, in matcher order (new rules last).
    # @param keywords [Array<Keyword>] the current rules
    def keywords_after(keywords)
      case action
      when "create" then keywords + [ Keyword.new(name: name, subcategory_id: subcategory_id, **amounts) ]
      when "update"
        keywords.map do |kw|
          kw.id == keyword.id ? kw.dup.tap { _1.assign_attributes(id: kw.id, name: name, subcategory_id: subcategory_id, **amounts) } : kw
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

    def amounts
      { min_amount: min_amount, max_amount: max_amount }
    end

    # True when an update would leave the rule exactly as it is.
    def no_op?
      action == "update" && parsed_name == keyword.parsed_name && subcategory_id == keyword.subcategory_id &&
        min_amount == keyword.min_amount && max_amount == keyword.max_amount
    end

    private

    def amount(value, current)
      return (action == "update" ? current : nil) if value.equal?(KEEP)

      value.presence && BigDecimal(value.to_s).round(2)
    end
  end
end
