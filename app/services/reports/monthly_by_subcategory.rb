module Reports
  class MonthlyBySubcategory
    def self.call
      new.call
    end

    def call
      all_transactions = Transaction.includes(subcategory: :category).to_a

      {
        credit: build_report(all_transactions.select { |t| t.transaction_type == "credit" }),
        debit: build_report(all_transactions.select { |t| t.transaction_type == "debit" })
      }
    end

    private

    def build_report(transactions)
      transactions.group_by { |t| t.transaction_date.strftime("%Y-%m") }.each_with_object({}) do |(month, monthly_transactions), result|
        subcategories = monthly_transactions.group_by { |t| t.subcategory.parsed_name }
    
        result[month] = subcategories.map do |subcat_name, subcat_transactions|
          subcategory = subcat_transactions.first.subcategory
    
          {
            name: subcat_name,
            total: subcat_transactions.sum { |t| t.amount.abs }.round(2).to_f,
            color_code: subcategory.color_code,
            transactions: subcat_transactions.map do |t|
              {
                name: t.parsed_name || t.name,
                amount: t.amount.round(2).to_f
              }
            end
          }
        end
      end
    end
    
  end
end
