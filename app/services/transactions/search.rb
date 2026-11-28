module Transactions
  # Filters, sorts and paginates transactions for the transactions screen.
  #
  # Params (all optional): from / to (ISO dates, inclusive; either may be left open), month
  # ("YYYY-MM", used when neither from nor to is given), monthly_statement_id, category_id,
  # subcategory_id, transaction_type, q (text in the name), unknown ("true": only transactions
  # marked "no idea"), sort (one of SORTS, default "date_desc"), page (1-based), per_page (max
  # MAX_PER_PAGE). Invalid dates and sorts are ignored.
  class Search
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 200

    # Each sort ends with id so pages never shuffle rows with equal values. Amounts are always
    # positive (the type says debit or credit), so the amount sorts go by size.
    SORTS = {
      "date_desc" => "transactions.transaction_date DESC, transactions.id DESC",
      "date_asc" => "transactions.transaction_date ASC, transactions.id ASC",
      "amount_desc" => "transactions.amount DESC, transactions.transaction_date DESC, transactions.id DESC",
      "amount_asc" => "transactions.amount ASC, transactions.transaction_date DESC, transactions.id DESC",
      "name_asc" => "LOWER(transactions.name) ASC, transactions.transaction_date DESC, transactions.id DESC",
      "name_desc" => "LOWER(transactions.name) DESC, transactions.transaction_date DESC, transactions.id DESC",
      "category_asc" => "LOWER(categories.name) ASC, LOWER(subcategories.name) ASC, transactions.transaction_date DESC, transactions.id DESC",
      "category_desc" => "LOWER(categories.name) DESC, LOWER(subcategories.name) DESC, transactions.transaction_date DESC, transactions.id DESC"
    }.freeze
    DEFAULT_SORT = "date_desc".freeze

    Result = Struct.new(:transactions, :total_count, :total_amount, :page, :per_page, :months, :sort,
                        :from, :to, :first_date, :last_date, keyword_init: true)

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = params
    end

    def call
      scope = filtered_scope
      first_date, last_date = Transaction.pick(Arel.sql("MIN(transaction_date)"), Arel.sql("MAX(transaction_date)"))
      Result.new(
        transactions: sorted(scope).includes(subcategory: :category, pending_category_suggestion: { subcategory: :category })
                                   .offset((page - 1) * per_page)
                                   .limit(per_page)
                                   .to_a,
        total_count: scope.count,
        total_amount: scope.sum(:amount).to_f.round(2),
        page: page,
        per_page: per_page,
        months: available_months,
        sort: sort,
        from: date_range&.begin&.to_date,
        to: date_range&.end&.to_date,
        first_date: first_date&.to_date,
        last_date: last_date&.to_date
      )
    end

    private

    attr_reader :params

    def filtered_scope
      scope = Transaction.all
      scope = scope.where(transaction_date: date_range) if date_range
      scope = scope.where(monthly_statement_id: params[:monthly_statement_id]) if params[:monthly_statement_id].present?
      scope = scope.where(subcategory_id: params[:subcategory_id]) if params[:subcategory_id].present?
      scope = scope.joins(:subcategory).where(subcategories: { category_id: params[:category_id] }) if params[:category_id].present?
      scope = scope.where(transaction_type: params[:transaction_type]) if params[:transaction_type].present?
      scope = search(scope) if params[:q].present?
      scope = scope.marked_unknown if ActiveModel::Type::Boolean.new.cast(params[:unknown])
      scope
    end

    def search(scope)
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      parsed = "%#{ActiveRecord::Base.sanitize_sql_like(StringUtils.default_string_parse(params[:q]))}%"
      scope.where("transactions.name ILIKE :term OR transactions.parsed_name ILIKE :parsed", term: term, parsed: parsed)
    end

    def sort
      SORTS.key?(params[:sort].to_s) ? params[:sort].to_s : DEFAULT_SORT
    end

    def sorted(scope)
      scope = scope.joins(subcategory: :category) if sort.start_with?("category")
      scope.order(Arel.sql(SORTS.fetch(sort)))
    end

    # from..to (whole days, either end may be open), else the month, else nil.
    def date_range
      return @date_range if defined?(@date_range)

      from, to = parse_date(params[:from]), parse_date(params[:to])
      from, to = to, from if from && to && from > to
      @date_range =
        if from || to
          (from&.beginning_of_day)..(to&.end_of_day)
        else
          month_range
        end
    end

    def month_range
      month = Date.strptime(params[:month].to_s, "%Y-%m")
      month.beginning_of_month.beginning_of_day..month.end_of_month.end_of_day
    rescue Date::Error
      nil
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end

    def page
      [ params[:page].to_i, 1 ].max
    end

    def per_page
      value = params[:per_page].to_i
      value.positive? ? [ value, MAX_PER_PAGE ].min : DEFAULT_PER_PAGE
    end

    # Every month that has transactions, newest first, so the client can offer a month picker.
    def available_months
      Transaction.distinct
                 .pluck(Arel.sql("to_char(transaction_date, 'YYYY-MM')"))
                 .sort
                 .reverse
    end
  end
end
