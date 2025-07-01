class ReportGenerator
  def initialize(data_by_month)
    @data_by_month = data_by_month # { "02_2025" => { csv: [...], pdf: [...] } }
    @report = {}
  end

  def call
    @data_by_month.each do |month, sources|
      all_entries = (sources[:csv] || []) + (sources[:pdf] || [])
      grouped = all_entries.group_by { |entry| [entry[:category], entry[:subcategory]] }

      @report[month] = grouped.transform_values do |entries|
        entries.sum { |entry| entry[:type] == 'debit' ? -entry[:amount] : entry[:amount] }
      end
    end

    @report
  end

  def self.call(data_by_month)
    new(data_by_month).call
  end

  def print_report
    @report.each do |month, totals|
      puts "\n📅 Report for #{month}:"
      total_expended = 0
      total_earned = 0
      total_invested = 0
      
      # Group by category and sum subcategories
      category_totals = totals.group_by { |(cat, _), _| cat }
      
      category_totals.each do |category, subcategory_entries|
        puts "\n#{category.upcase}"
        subcategory_totals = {}
        
        subcategory_entries.each do |(category, subcategory), total|
          subcategory_totals[subcategory] ||= 0
          subcategory_totals[subcategory] += total
        end
        
        category_total = 0
        subcategory_totals.each do |subcategory, total|
          color = color_for({ amount: total, type: total.negative? ? 'debit' : 'credit' })
          puts "  #{color}  R$ #{'%.2f' % total} - #{subcategory}\e[0m"
          category_total += total
          total_expended += total if total.negative?
          total_earned += total if total.positive?
          total_invested += total.abs if category == 'investments' 
        end
        
        puts "    R$ #{'%.2f' % category_total} - Total for #{category.upcase}\e[0m"
      end
      
      puts "\n🧾 R$ #{'%.2f' % total_expended} - Total Expended"
      puts "🧾 R$ #{'%.2f' % total_earned} - Total Earned"
      puts "🧾 R$ #{'%.2f' % (total_earned - total_expended.abs)} - Difference"
      puts "🧾 R$ #{'%.2f' % total_invested} - Total Invested"
      puts "🧾 R$ #{'%.2f' % (total_earned.to_f - (total_expended.abs - total_invested.to_f))} - Total Earned - (Total Expended - Total Invested)\n\n"
    end
    puts "\n\n🚀 Done!\n\n"
  end

  def print_single_month_report(month)
    totals = @report[month]
    return if totals.nil?

    puts "\n📅 Report for #{month}:"
    total_expended = 0
    total_earned = 0
    total_invested = 0
    
    # Group by category and sum subcategories
    category_totals = totals.group_by { |(cat, _), _| cat }
    
    category_totals.each do |category, subcategory_entries|
      puts "\n#{category.upcase}"
      subcategory_totals = {}
      
      subcategory_entries.each do |(category, subcategory), total|
        subcategory_totals[subcategory] ||= 0
        subcategory_totals[subcategory] += total
      end
      
      category_total = 0
      subcategory_totals.each do |subcategory, total|
        color = color_for({ amount: total, type: total.negative? ? 'debit' : 'credit' })
        puts "  #{color}  R$ #{'%.2f' % total} - #{subcategory}\e[0m"
        category_total += total
        total_expended += total if total.negative?
        total_earned += total if total.positive?
        total_invested += total.abs if category == 'investments' 
      end
      
      puts "    R$ #{'%.2f' % category_total} - Total for #{category.upcase}\e[0m"
    end
    
    puts "\n🧾 R$ #{'%.2f' % total_expended} - Total Expended"
    puts "🧾 R$ #{'%.2f' % total_earned} - Total Earned"
    puts "🧾 R$ #{'%.2f' % (total_earned - total_expended.abs)} - Difference"
    puts "🧾 R$ #{'%.2f' % total_invested} - Total Invested"
    puts "🧾 R$ #{'%.2f' % (total_earned.to_f - (total_expended.abs - total_invested.to_f))} - Total Earned - (Total Expended - Total Invested)\n\n"
  end
end
