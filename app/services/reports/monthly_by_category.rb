module Reports
  class MonthlyByCategory
    def self.call
      new.call
    end

    def call
      transactions = Transaction.all.includes(subcategory: :category)

      grouped = transactions.group_by { |t| t.transaction_date.strftime("%Y-%m") }

      grouped.each_with_object({}) do |(month, monthly_transactions), result|
        result[month] = monthly_transactions.group_by { |t| t.subcategory.category.parsed_name }.each_with_object({}) do |(category_name, category_transactions), cat_hash|
          category = category_transactions.first.subcategory.category

          cat_hash[category_name] = {
            color_code: category.color_code,
            subcategories: category_transactions.group_by { |t| t.subcategory.parsed_name }.each_with_object({}) do |(subcategory_name, subcat_transactions), subcat_hash|
              subcat_hash[subcategory_name] = {
                total: subcat_transactions.sum { |t| t.amount.abs },
                transactions: subcat_transactions.map do |t|
                  {
                    name: t.parsed_name || t.name,
                    amount: t.amount.round(2),
                    transaction_date: t.transaction_date.to_s
                  }
                end
              }
            end
          }
        end
      end
    end
  end
end
