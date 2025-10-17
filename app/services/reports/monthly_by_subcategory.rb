# app/services/reports/monthly_by_subcategory.rb
module Reports
  class MonthlyBySubcategory
    def self.call
      new.call
    end

    def call
      all = Transaction.includes(subcategory: :category).to_a

      {
        credit:  build_report(all.select { |t| t.transaction_type == "credit" }),
        debit:   build_report(all.select { |t| t.transaction_type == "debit"  })
      }
    end

    private

    def build_report(transactions)
      transactions.group_by { |t| t.transaction_date.strftime("%Y-%m") }.each_with_object({}) do |(month, txs), result|
        total_transfered = 0
        total_invested = 0
        total_expended = 0
        total_received = 0
        subcat_entries = txs.group_by { |t| t.subcategory.parsed_name }.map do |subcat_name, subt|
          sub = subt.first.subcategory
          total = subt.sum { |t| t.amount.abs }.round(2).to_f

          case sub.subcategory_type
          when 'transfer'
            total_transfered += total.abs
          when 'investment'
            total_invested += total.abs
          when 'expense'
            total_expended += total.abs
          when 'gain'
            total_received += total.abs
          end

          {
            name:         subcat_name,
            total:        total,
            color_code:   sub.color_code,
            transactions: subt.map { |t|
              { name: t.parsed_name || t.name,
                transaction_date: t.transaction_date.strftime("%d/%m/%Y"),
                amount: t.amount.round(2).to_f }
            }
          }
        end

        month_total = subcat_entries.sum { |h| h[:total] }.round(2)

        result[month] = {
          subcategories: subcat_entries,
          total:         month_total,
          total_transfered: total_transfered,
          total_invested: total_invested,
          total_expended: total_expended,
          total_received: total_received
        }
      end
    end
  end
end
