module Reports
  class MonthlyBySubcategory
    def self.call
      new.call
    end

    def call
      transactions = Transaction.all.includes(subcategory: :category)

      grouped_by_month = transactions.group_by { |t| t.transaction_date.strftime("%Y-%m") }

      grouped_by_month.each_with_object({}) do |(month, monthly_transactions), result|
        subcategories = monthly_transactions.group_by { |t| t.subcategory.parsed_name }

        result[month] = subcategories.map do |subcat_name, subcat_transactions|
          subcategory = subcat_transactions.first.subcategory
        
          {
            name: subcat_name,
            total: subcat_transactions.sum { |t| t.amount.abs }.round(2).to_f,
            color_code: subcategory.color_code
          }
        end        
      end
    end
  end
end
