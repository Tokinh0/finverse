module Reports
  # One-screen financial health report.
  #
  # - summary:    income, spending, invested, net and savings rate for the last `period` months
  #               (ending at `as_of`), next to the same-length period before it
  # - categories: spending per category in that period, with share and change vs the previous one
  # - trends:     monthly spending per category over the last 12 months, with last month vs the
  #               month before and vs the 6 months before it
  # - year:       a calendar year month by month against the previous year, category totals,
  #               top merchants and the best and worst months. Totals of a year in progress are
  #               compared with the same months of the previous year.
  #
  # Definitions: income = credits in "gain" subcategories; spending = debits minus refunds in
  # "expense" subcategories; invested = debits minus redemptions in "investment" subcategories.
  # Transfers between the owner's own accounts count as neither.
  class FinancialHealth
    PERIODS = [ 1, 3, 6, 12 ].freeze
    DEFAULT_PERIOD = 3
    TREND_MONTHS = 12
    AVERAGE_MONTHS = 6
    TOP_MERCHANTS = 8

    def self.call(**args)
      new(**args).call
    end

    def initialize(period: nil, as_of: nil, year: nil)
      @period = PERIODS.include?(period.to_i) ? period.to_i : DEFAULT_PERIOD
      @as_of = parse_month(as_of) || latest_month
      @year = year.to_i.positive? ? year.to_i : @as_of&.year
    end

    def call
      return empty_report unless @as_of

      {
        as_of: month_key(@as_of),
        period_months: @period,
        range: range_json(current_range),
        previous_range: range_json(previous_range),
        months_available: months_available,
        years_available: months_available.map { |m| m[0, 4].to_i }.uniq,
        summary: { current: totals(in_range(current_range)), previous: totals(in_range(previous_range)) },
        categories: category_breakdown,
        trends: trends,
        year: year_summary
      }
    end

    private

    # ---- data -----------------------------------------------------------------------------------

    def transactions
      @transactions ||= begin
        from = [ previous_range.begin, trend_months.first, Date.new(@year - 1, 1, 1) ].min
        Transaction.includes(subcategory: :category)
                   .where(transaction_date: from.beginning_of_day..)
                   .to_a
      end
    end

    # Signed contribution of a transaction to income / spending / invested, or nil when it doesn't count.
    def classify(transaction)
      sign = transaction.debit? ? 1 : (transaction.credit? ? -1 : 0)
      case transaction.subcategory&.subcategory_type
      when "gain" then [ :income, transaction.amount ] if transaction.credit?
      when "expense" then [ :expense, transaction.amount * sign ]
      when "investment" then [ :invested, transaction.amount * sign ]
      end
    end

    def in_range(range)
      transactions.select { |t| range.cover?(t.transaction_date.to_date) }
    end

    def expenses_of(list)
      list.sum { |t| (kind, value = classify(t)) && kind == :expense ? value : 0 }
    end

    def totals(list)
      sums = Hash.new(0)
      list.each do |t|
        kind, value = classify(t)
        sums[kind] += value if kind
      end
      income = sums[:income]
      net = income - sums[:expense]

      {
        income: money(income),
        expenses: money(sums[:expense]),
        invested: money(sums[:invested]),
        net: money(net),
        savings_rate: income.positive? ? (net / income).to_f.round(4) : nil
      }
    end

    # ---- sections -------------------------------------------------------------------------------

    def category_breakdown
      current = in_range(current_range)
      previous = in_range(previous_range)
      total = expenses_of(current)

      expense_categories.map do |category|
        spent = expenses_of(current.select { |t| t.subcategory.category_id == category.id })
        before = expenses_of(previous.select { |t| t.subcategory.category_id == category.id })
        subcategories = current.select { |t| t.subcategory.category_id == category.id }
                               .group_by(&:subcategory)
                               .map { |sub, list| { id: sub.id, name: sub.name, total: money(expenses_of(list)) } }
                               .sort_by { |s| -s[:total] }

        category_json(category).merge(
          total: money(spent),
          share: total.positive? ? (spent / total).to_f.round(4) : 0,
          previous_total: money(before),
          change_pct: change(spent, before),
          subcategories: subcategories
        )
      end.sort_by { |c| -c[:total] }
    end

    def trends
      by_month = trend_months.index_with { |month| in_range(month..month.end_of_month) }

      categories = expense_categories.map do |category|
        values = trend_months.map do |month|
          expenses_of(by_month[month].select { |t| t.subcategory.category_id == category.id })
        end
        last, prior = values[-1], values[-2]
        average = values[-(AVERAGE_MONTHS + 1)...-1].sum / AVERAGE_MONTHS

        category_json(category).merge(
          values: values.map { |v| money(v) },
          last_month: money(last),
          previous_month: money(prior),
          average: money(average),
          change_vs_previous_pct: change(last, prior),
          change_vs_average_pct: change(last, average)
        )
      end

      {
        months: trend_months.map { |m| month_key(m) },
        totals: trend_months.map { |m| money(expenses_of(by_month[m])) },
        categories: categories.sort_by { |c| -c[:values].sum }
      }
    end

    def year_summary
      current = transactions.select { |t| t.transaction_date.year == @year }
      previous = transactions.select { |t| t.transaction_date.year == @year - 1 }
      monthly = (1..12).map do |month|
        this_month = current.select { |t| t.transaction_date.month == month }
        last_year = previous.select { |t| t.transaction_date.month == month }
        totals(this_month).merge(
          month: month,
          has_data: this_month.any?,
          previous_year_expenses: last_year.any? ? money(expenses_of(last_year)) : nil
        )
      end
      with_data = monthly.select { |m| m[:has_data] }
      # Compare a year in progress with the same months of the previous year, not all of it.
      through_month = with_data.map { |m| m[:month] }.max || 12
      previous_same_months = previous.select { |t| t.transaction_date.month <= through_month }

      {
        year: @year,
        previous_year: @year - 1,
        months_with_data: with_data.size,
        compared_through_month: through_month,
        totals: totals(current),
        previous_totals: previous_same_months.any? ? totals(previous_same_months) : nil,
        monthly: monthly,
        best_month: with_data.max_by { |m| m[:net] }&.slice(:month, :net, :income, :expenses),
        worst_month: with_data.min_by { |m| m[:net] }&.slice(:month, :net, :income, :expenses),
        categories: expense_categories.map do |category|
          spent = expenses_of(current.select { |t| t.subcategory.category_id == category.id })
          before = expenses_of(previous_same_months.select { |t| t.subcategory.category_id == category.id })
          category_json(category).merge(total: money(spent), previous_total: money(before), change_pct: change(spent, before))
        end.sort_by { |c| -c[:total] },
        top_merchants: top_merchants(current)
      }
    end

    def top_merchants(list)
      list.select { |t| t.debit? && t.subcategory&.expense? }
          .group_by { |t| Transactions::Merchant.key(t) }
          .map do |_key, charges|
            name = charges.group_by(&:name).max_by { |_n, same| same.size }.first
            { name: name, total: money(charges.sum(&:amount)), count: charges.size,
              subcategory: charges.first.subcategory.name }
          end
          .sort_by { |m| -m[:total] }
          .first(TOP_MERCHANTS)
    end

    # ---- helpers --------------------------------------------------------------------------------

    def expense_categories
      @expense_categories ||= Category.joins(:subcategories).where(subcategories: { subcategory_type: "expense" })
                                      .distinct.order(:id).to_a
    end

    def current_range
      (@as_of - (@period - 1).months).beginning_of_month..@as_of.end_of_month
    end

    def previous_range
      start = current_range.begin - @period.months
      start..(current_range.begin - 1.day)
    end

    def trend_months
      @trend_months ||= (0...TREND_MONTHS).map { |i| @as_of - (TREND_MONTHS - 1 - i).months }
    end

    def months_available
      @months_available ||= Transaction.distinct
                                       .pluck(Arel.sql("to_char(transaction_date, 'YYYY-MM')"))
                                       .sort.reverse
    end

    def category_json(category)
      { id: category.id, name: category.name, color_code: category.color_code }
    end

    def range_json(range)
      { from: range.begin.iso8601, to: range.end.iso8601 }
    end

    def change(current, previous)
      return nil unless previous.positive?

      ((current - previous) / previous).to_f.round(4)
    end

    def money(value)
      value.to_f.round(2)
    end

    def month_key(date)
      date.strftime("%Y-%m")
    end

    def parse_month(value)
      Date.strptime(value.to_s, "%Y-%m") if value.present?
    rescue Date::Error
      nil
    end

    def latest_month
      Transaction.maximum(:transaction_date)&.to_date&.beginning_of_month
    end

    def empty_report
      { as_of: nil, period_months: @period, months_available: [], years_available: [] }
    end
  end
end
