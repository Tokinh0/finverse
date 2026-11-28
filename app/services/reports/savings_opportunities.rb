module Reports
  # Where the owner could spend less, for the financial health report. It compares the selected
  # period (`period` months ending at `as_of`) with the BASELINE_MONTHS months before it, using
  # monthly averages so periods of different lengths compare fairly. Only debits in "expense"
  # subcategories count. Merchants are grouped with Transactions::Merchant.key.
  #
  # Opportunities (each with what it would save per month, `potential_monthly`):
  # - growing_merchant:    a merchant you now spend clearly more on than before (e.g. delivery);
  #                        saving = back to the usual monthly level. Shows orders per month and
  #                        average ticket then and now, and the last 12 months.
  # - frequent_small:      many small charges at one merchant that add up; saving = one in
  #                        SMALL_CUT of them.
  # - growing_subcategory: a subcategory above its usual level, minus what the merchants above
  #                        already explain.
  # - fees:                bank fees, interest and fines (FEE_WORDS); saving = all of it.
  # - subscriptions:       one charge a month at a fixed price (at most one price change), still
  #                        active. Price increases are flagged. Their cost is shown to review, not
  #                        added to the total, since only the owner knows which ones are worth it.
  #                        Subscription and fee charges are left out of the other opportunities.
  class SavingsOpportunities
    BASELINE_MONTHS = 12
    SERIES_MONTHS = 12
    MIN_BASELINE_MONTHS = 3
    MIN_MONTHLY = 50          # R$ per month an opportunity must be worth
    GROWTH = 0.2              # +20% over the usual level
    SMALL_TICKET = 80         # R$ per charge
    SMALL_PER_MONTH = 4       # charges per month
    SMALL_MIN_MONTHLY = 100   # R$ per month
    SMALL_CUT = 3             # skip one in three
    SUBSCRIPTION_WINDOW = 6   # months looked at
    SUBSCRIPTION_MIN_MONTHS = 3
    SUBSCRIPTION_TOLERANCE = 0.02 # same price, give or take rounding and IOF
    PRICE_INCREASE = 0.03
    MAX_PRICE_CHANGE = 0.5        # a bigger jump isn't a subscription getting pricier
    FEE_WORDS = %w[TARIFA IOF JUROS MULTA ANUIDADE ENCARGO MORA].freeze
    INSTALLMENT = %r{\bPARC|\b\d{1,2}\s*/\s*\d{1,2}\b}i # "PARC 02/10", "03/12": a purchase in installments
    MAX_ITEMS = 12

    def self.call(**args)
      new(**args).call
    end

    # @param as_of [Date] first day of the last month of the period
    # @param period [Integer] months in the period
    def initialize(as_of:, period:)
      @as_of = as_of
      @period = period
    end

    def call
      return empty if @as_of.nil?

      fee_items = fees
      subscription_items = subscriptions
      taken = (fee_items[:keys] + subscription_items.map { |s| s[:key] }).to_set
      merchant_items = merchants(taken)
      opportunities = merchant_items + subcategories(merchant_items, taken)
      opportunities << fee_items[:opportunity] if fee_items[:opportunity]
      opportunities.sort_by! { |o| -o[:potential_monthly] }
      monthly = opportunities.sum { |o| o[:potential_monthly] }

      {
        period_months: @period,
        baseline_months: baseline_months.size,
        current_range: range_json(current_range),
        baseline_range: baseline_months.any? ? range_json(baseline_months.first..baseline_months.last.end_of_month) : nil,
        summary: {
          potential_monthly: money(monthly),
          potential_yearly: money(monthly * 12),
          spending_now: money(monthly_average(current_charges)),
          spending_before: baseline_months.any? ? money(sum(baseline_charges) / baseline_months.size) : nil,
          lowest_month: lowest_month
        },
        opportunities: opportunities.first(MAX_ITEMS),
        subscriptions: {
          monthly: money(subscription_items.sum { |s| s[:monthly] }),
          yearly: money(subscription_items.sum { |s| s[:monthly] } * 12),
          items: subscription_items.map { |s| s.except(:key) }
        }
      }
    end

    private

    # ---- data -----------------------------------------------------------------------------------

    def charges
      @charges ||= Transaction.includes(subcategory: :category)
                              .where(transaction_type: "debit",
                                     transaction_date: earliest.beginning_of_day..current_range.end.end_of_day)
                              .select { |t| t.subcategory&.expense? }
    end

    def earliest
      [ current_range.begin - BASELINE_MONTHS.months, series_months.first ].min
    end

    def current_range
      @current_range ||= (@as_of - (@period - 1).months).beginning_of_month..@as_of.end_of_month
    end

    def current_charges
      @current_charges ||= charges.select { |t| current_range.cover?(t.transaction_date.to_date) }
    end

    # The months before the period that have any transaction at all (a merchant missing from one
    # of them counts as zero that month; months before the first statement don't count).
    def baseline_months
      @baseline_months ||= begin
        start = current_range.begin - BASELINE_MONTHS.months
        with_data = Transaction.where(transaction_date: start.beginning_of_day...current_range.begin.beginning_of_day)
                               .pluck(:transaction_date).map { |d| d.to_date.beginning_of_month }.uniq
        with_data.sort
      end
    end

    def baseline_charges
      @baseline_charges ||= begin
        months = baseline_months.to_set
        charges.select { |t| months.include?(t.transaction_date.to_date.beginning_of_month) }
      end
    end

    def series_months
      @series_months ||= (0...SERIES_MONTHS).map { |i| @as_of - (SERIES_MONTHS - 1 - i).months }
    end

    def by_merchant(list)
      list.group_by { |t| Transactions::Merchant.key(t) }
    end

    # ---- opportunities --------------------------------------------------------------------------

    def merchants(taken)
      now_by = by_merchant(current_charges)
      before_by = by_merchant(baseline_charges)
      all_by = by_merchant(charges)

      now_by.filter_map do |key, now|
        next if taken.include?(key) || key.blank?

        before = before_by[key] || []
        growing(key, now, before, all_by[key]) || frequent_small(key, now, all_by[key])
      end
    end

    def growing(key, now, before, all)
      return nil if baseline_months.size < MIN_BASELINE_MONTHS

      monthly_now = monthly_average(now)
      monthly_before = sum(before) / baseline_months.size
      saving = monthly_now - monthly_before
      return nil unless saving >= MIN_MONTHLY && monthly_now >= monthly_before * (1 + GROWTH)

      merchant_json("growing_merchant", key, now, all).merge(
        monthly_now: money(monthly_now),
        monthly_before: money(monthly_before),
        count_now: per_month(now.size, @period),
        count_before: per_month(before.size, baseline_months.size),
        ticket_now: money(average_ticket(now)),
        ticket_before: before.any? ? money(average_ticket(before)) : nil,
        potential_monthly: money(saving)
      )
    end

    def frequent_small(key, now, all)
      per_month = now.size.to_f / @period
      monthly_now = monthly_average(now)
      ticket = average_ticket(now)
      return nil unless per_month >= SMALL_PER_MONTH && ticket <= SMALL_TICKET && monthly_now >= SMALL_MIN_MONTHLY

      merchant_json("frequent_small", key, now, all).merge(
        monthly_now: money(monthly_now),
        count_now: per_month.round(1),
        ticket_now: money(ticket),
        potential_monthly: money(monthly_now / SMALL_CUT)
      )
    end

    def subcategories(merchant_items, taken)
      return [] if baseline_months.size < MIN_BASELINE_MONTHS

      explained = Hash.new(0)
      merchant_items.each { |m| explained[m[:subcategory][:id]] += m[:potential_monthly] }
      variable = ->(list) { list.reject { |t| taken.include?(Transactions::Merchant.key(t)) } }
      before_by = variable.(baseline_charges).group_by(&:subcategory)

      variable.(current_charges).group_by(&:subcategory).filter_map do |subcategory, now|
        monthly_now = monthly_average(now)
        monthly_before = sum(before_by[subcategory] || []) / baseline_months.size
        saving = monthly_now - monthly_before - explained[subcategory.id]
        next unless saving >= MIN_MONTHLY && monthly_now >= monthly_before * (1 + GROWTH)

        {
          kind: "growing_subcategory",
          name: subcategory.name,
          subcategory: subcategory_json(subcategory),
          monthly_now: money(monthly_now),
          monthly_before: money(monthly_before),
          potential_monthly: money(saving),
          series: series(charges.select { |t| t.subcategory_id == subcategory.id }),
          top_merchants: by_merchant(now).map { |_k, list| { name: display_name(list), monthly: money(monthly_average(list)) } }
                                         .sort_by { |m| -m[:monthly] }.first(3)
        }
      end
    end

    def fees
      list = current_charges.select { |t| fee?(t) }
      keys = list.map { |t| Transactions::Merchant.key(t) }.uniq
      monthly = monthly_average(list)
      return { keys: keys, opportunity: nil } if list.empty?

      opportunity = {
        kind: "fees",
        name: nil,
        monthly_now: money(monthly),
        potential_monthly: money(monthly),
        count_now: per_month(list.size, @period),
        series: series(charges.select { |t| fee?(t) }),
        items: by_merchant(list).map { |_k, same| { name: display_name(same), total: money(sum(same)), count: same.size } }
                                .sort_by { |i| -i[:total] }.first(5)
      }
      { keys: keys, opportunity: opportunity }
    end

    def fee?(transaction)
      key = Transactions::Merchant.key(transaction)
      FEE_WORDS.any? { |word| key.include?(word) }
    end

    # Merchants charged once a month at a fixed price (one price change allowed), charged in the
    # last two months of the period.
    def subscriptions
      window = (0...SUBSCRIPTION_WINDOW).map { |i| (@as_of - i.months).beginning_of_month }.to_set
      recent = charges.select { |t| window.include?(t.transaction_date.to_date.beginning_of_month) }
      active_since = (@as_of - 1.month).beginning_of_month

      by_merchant(recent).filter_map do |key, list|
        next if key.blank? || list.any? { |t| fee?(t) || t.name.to_s.match?(INSTALLMENT) }

        by_month = list.group_by { |t| t.transaction_date.to_date.beginning_of_month }
        next if by_month.size < SUBSCRIPTION_MIN_MONTHS || by_month.values.any? { |same| same.size > 1 }
        next if by_month.keys.max < active_since

        amounts = list.sort_by(&:transaction_date).map(&:amount)
        next if price_levels(amounts) > 2 || (amounts.max - amounts.min) > amounts.min * MAX_PRICE_CHANGE

        first, last = amounts.first, amounts.last
        {
          key: key,
          name: display_name(list),
          subcategory: subcategory_json(list.last.subcategory),
          monthly: money(last),
          months: by_month.size,
          last_charge: list.max_by(&:transaction_date).transaction_date.to_date.iso8601,
          price_change: last > first * (1 + PRICE_INCREASE) ? { from: money(first), to: money(last) } : nil
        }
      end.sort_by { |s| -s[:monthly] }
    end

    # ---- helpers --------------------------------------------------------------------------------

    # How many times the price changed, plus one: consecutive charges within the tolerance are
    # the same price.
    def price_levels(amounts)
      amounts.each_cons(2).count { |a, b| (b - a).abs > a * SUBSCRIPTION_TOLERANCE } + 1
    end

    def merchant_json(kind, key, now, all)
      subcategory = now.group_by(&:subcategory).max_by { |_s, same| sum(same) }.first
      {
        kind: kind,
        name: display_name(now),
        query: key.tr("_", " "),
        subcategory: subcategory_json(subcategory),
        first_seen: all.min_by(&:transaction_date).transaction_date.to_date.strftime("%Y-%m"),
        series: series(all)
      }
    end

    # The most common raw name of the merchant's charges, without a trailing order number.
    def display_name(list)
      list.map { |t| t.name.to_s.sub(/[\s*#-]*\d+\s*\z/, "").strip }.tally.max_by { |_n, count| count }.first
    end

    def series(list)
      totals = list.group_by { |t| t.transaction_date.to_date.beginning_of_month }.transform_values { |same| sum(same) }
      series_months.map { |m| { month: m.strftime("%Y-%m"), total: money(totals[m] || 0) } }
    end

    def lowest_month
      totals = baseline_charges.group_by { |t| t.transaction_date.to_date.beginning_of_month }.transform_values { |list| sum(list) }
      month, total = totals.min_by { |_m, value| value }
      month && { month: month.strftime("%Y-%m"), total: money(total) }
    end

    def subcategory_json(subcategory)
      category = subcategory.category
      { id: subcategory.id, name: subcategory.name, category: category&.name, color_code: subcategory.color_code || category&.color_code }
    end

    def sum(list)
      list.sum(&:amount)
    end

    def monthly_average(list)
      sum(list) / @period
    end

    def average_ticket(list)
      list.empty? ? 0 : sum(list) / list.size
    end

    def per_month(count, months)
      months.positive? ? (count.to_f / months).round(1) : 0
    end

    def money(value)
      value.to_f.round(2)
    end

    def range_json(range)
      { from: range.begin.iso8601, to: range.end.iso8601 }
    end

    def empty
      { period_months: @period, baseline_months: 0, opportunities: [], subscriptions: { monthly: 0, yearly: 0, items: [] } }
    end
  end
end
