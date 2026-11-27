module Transactions
  # Filters and paginates transactions for the review screen.
  #
  # Params (all optional): month ("YYYY-MM"), category_id, subcategory_id, transaction_type,
  # q (text in the name), page (1-based), per_page (max MAX_PER_PAGE).
  class Search
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 200

    Result = Struct.new(:transactions, :total_count, :total_amount, :page, :per_page, :months, keyword_init: true)

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = params
    end

    def call
      scope = filtered_scope
      Result.new(
        transactions: scope.includes(subcategory: :category)
                           .order(transaction_date: :desc, id: :desc)
                           .offset((page - 1) * per_page)
                           .limit(per_page)
                           .to_a,
        total_count: scope.count,
        total_amount: scope.sum(:amount).to_f.round(2),
        page: page,
        per_page: per_page,
        months: available_months
      )
    end

    private

    attr_reader :params

    def filtered_scope
      scope = Transaction.all
      scope = scope.where(transaction_date: month_range) if month_range
      scope = scope.where(subcategory_id: params[:subcategory_id]) if params[:subcategory_id].present?
      scope = scope.joins(:subcategory).where(subcategories: { category_id: params[:category_id] }) if params[:category_id].present?
      scope = scope.where(transaction_type: params[:transaction_type]) if params[:transaction_type].present?
      scope = search(scope) if params[:q].present?
      scope
    end

    def search(scope)
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      parsed = "%#{ActiveRecord::Base.sanitize_sql_like(StringUtils.default_string_parse(params[:q]))}%"
      scope.where("transactions.name ILIKE :term OR transactions.parsed_name ILIKE :parsed", term: term, parsed: parsed)
    end

    def month_range
      return @month_range if defined?(@month_range)

      @month_range = begin
        month = Date.strptime(params[:month].to_s, "%Y-%m")
        month.beginning_of_month.beginning_of_day..month.end_of_month.end_of_day
      rescue Date::Error
        nil
      end
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
