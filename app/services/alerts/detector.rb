module Alerts
  # Flags debits in one month that are worth a second look. History is the previous HISTORY_MONTHS
  # months. Dismissed alerts (AlertDismissal) are left out unless asked for.
  #
  # - duplicate:      same merchant and amount on the same day (classic double charge)
  # - new_merchant:   no keyword matched it (it fell into "Outros") and that merchant never
  #                   appeared in the history; categorized merchants are expected, so they're skipped
  # - amount_changed: a merchant charged once a month at a stable amount (subscriptions, bills)
  #                   whose amount moved
  # - unusual_amount: far above the median of its *expense* subcategory; transfers, investments
  #                   and the "Outros" catch-all have no meaningful "usual" amount
  #
  # Thresholds were tuned against real statements to keep the list short enough to review.
  class Detector
    HISTORY_MONTHS = 6
    NEW_MERCHANT_MIN_AMOUNT = 100
    RECURRING_MIN_MONTHS = 2
    RECURRING_STABLE_TOLERANCE = 0.01 # previous charges within 1% of each other
    RECURRING_CHANGE_THRESHOLD = 0.05 # this month differs by more than 5%
    UNUSUAL_MULTIPLIER = 3
    UNUSUAL_MIN_HISTORY = 5
    UNUSUAL_MIN_AMOUNT = 100

    Alert = Struct.new(:kind, :transaction, :message, :details, :dismissed, keyword_init: true)

    def self.call(month: nil, include_dismissed: false)
      new(month: month, include_dismissed: include_dismissed).call
    end

    def self.merchant_key(transaction)
      Transactions::Merchant.key(transaction)
    end

    attr_reader :month

    def initialize(month: nil, include_dismissed: false)
      @month = parse_month(month) || latest_month
      @include_dismissed = ActiveModel::Type::Boolean.new.cast(include_dismissed)
    end

    def call
      return [] unless month

      alerts = duplicates + new_merchants + amount_changes + unusual_amounts
      dismissed = AlertDismissal.where(parsed_transaction_id: alerts.map { |a| a.transaction.id })
                                .pluck(:parsed_transaction_id, :kind).to_set
      alerts.each { |alert| alert.dismissed = dismissed.include?([ alert.transaction.id, alert.kind ]) }
      alerts = alerts.reject(&:dismissed) unless @include_dismissed
      alerts.sort_by { |a| [ -a.transaction.transaction_date.to_i, a.kind ] }
    end

    private

    def month_range
      month.beginning_of_month.beginning_of_day..month.end_of_month.end_of_day
    end

    def current
      @current ||= debits.where(transaction_date: month_range).includes(subcategory: :category).to_a
    end

    def history
      @history ||= debits.where(transaction_date: (month - HISTORY_MONTHS.months).beginning_of_month...month.beginning_of_month).to_a
    end

    def debits
      Transaction.debit
    end

    def duplicates
      current.filter_map do |t|
        twin = current.find do |other|
          other.id < t.id && other.amount == t.amount && other.transaction_date.to_date == t.transaction_date.to_date &&
            self.class.merchant_key(other) == self.class.merchant_key(t)
        end
        next unless twin

        alert("duplicate", t, "Same merchant and amount as a charge on #{twin.transaction_date.to_date.strftime('%d/%m/%Y')}",
              related_transaction_id: twin.id)
      end
    end

    def new_merchants
      return [] if history.empty? # nothing to compare against yet

      known = history.map { |t| self.class.merchant_key(t) }.to_set
      first_seen = current.select { |t| t.subcategory&.fallback? }.group_by { |t| self.class.merchant_key(t) }.reject { |key, _| known.include?(key) }

      first_seen.values.filter_map do |charges|
        first = charges.min_by { |t| [ t.transaction_date, t.id ] }
        next if first.amount < NEW_MERCHANT_MIN_AMOUNT

        alert("new_merchant", first, "First charge from this merchant in the last #{HISTORY_MONTHS} months")
      end
    end

    # A merchant charged every month at a stable amount (subscriptions, bills) whose amount moved.
    def amount_changes
      by_merchant = history.group_by { |t| self.class.merchant_key(t) }

      current.filter_map do |t|
        monthly = (by_merchant[self.class.merchant_key(t)] || []).group_by { |h| h.transaction_date.strftime("%Y-%m") }
        next if monthly.size < RECURRING_MIN_MONTHS || monthly.values.any? { |charges| charges.size > 1 }

        amounts = monthly.values.flatten.map(&:amount)
        reference = amounts.sum / amounts.size
        next unless amounts.all? { |a| (a - reference).abs <= reference * RECURRING_STABLE_TOLERANCE }
        next unless (t.amount - reference).abs > reference * RECURRING_CHANGE_THRESHOLD

        alert("amount_changed", t, "Recurring charge changed from #{brl(reference)} to #{brl(t.amount)}",
              expected_amount: reference.to_f.round(2))
      end
    end

    def unusual_amounts
      by_subcategory = history.group_by(&:subcategory_id)

      current.filter_map do |t|
        next unless t.subcategory&.expense? && !t.subcategory.fallback?

        past = (by_subcategory[t.subcategory_id] || []).map(&:amount)
        next if past.size < UNUSUAL_MIN_HISTORY || t.amount < UNUSUAL_MIN_AMOUNT

        typical = median(past)
        next unless t.amount > typical * UNUSUAL_MULTIPLIER

        alert("unusual_amount", t, "#{(t.amount / typical).round(1)}× the usual #{brl(typical)} for #{t.subcategory.name}",
              expected_amount: typical.to_f.round(2))
      end
    end

    def alert(kind, transaction, message, details = {})
      Alert.new(kind: kind, transaction: transaction, message: message, details: details, dismissed: false)
    end

    def median(values)
      sorted = values.sort
      mid = sorted.size / 2
      sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    end

    def brl(value)
      format("R$ %.2f", value).tr(".", ",")
    end

    def parse_month(value)
      Date.strptime(value.to_s, "%Y-%m") if value.present?
    rescue Date::Error
      nil
    end

    def latest_month
      Transaction.debit.maximum(:transaction_date)&.to_date&.beginning_of_month
    end
  end
end
