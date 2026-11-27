module Reports
  # How transactions got their subcategory, month by month (by transaction date), so the owner
  # can see rules taking over: keyword rules vs accepted suggestions vs manual vs still open.
  module CategorizationProgress
    SOURCES = Transaction.categorization_sources.keys.freeze

    module_function

    # @param months [Integer] how many months back from the latest month with data
    def call(months: 6)
      latest = Transaction.maximum(:transaction_date)
      return [] unless latest

      from = (latest.to_date.beginning_of_month << (months - 1))
      counts = Transaction.where(transaction_date: from..latest.end_of_month)
                          .group(Arel.sql("to_char(transaction_date, 'YYYY-MM')"), :categorization_source).count

      (0...months).map { (from >> _1).strftime("%Y-%m") }.map do |month|
        by_source = SOURCES.to_h { [ _1, counts.fetch([ month, _1 ], 0) ] }
        total = by_source.values.sum
        { month: month, total: total, counts: by_source,
          keyword_share: total.zero? ? nil : (by_source["keyword"].to_f / total).round(3) }
      end
    end
  end
end
