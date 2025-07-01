# frozen_string_literal: true

require_relative 'pdf_parser'
require_relative 'csv_parser'
require_relative 'report_generator'
require_relative 'helper'
require 'pry'

include Helper

DATA_DIR = './data' # Change to your folder path

def extract_month_year(filename)
  match = filename.match(/(\d{2}_\d{4})/)
  match ? match[1] : 'unknown'
end

############################################ PARSE DATA ################################################################
grouped_data = {}
Dir.glob("#{DATA_DIR}/*.{csv,pdf}").each do |file|
  key = extract_month_year(File.basename(file))
  grouped_data[key] ||= {}

  if file.end_with?('.csv')
    grouped_data[key][:csv] = CsvParser.new(file).call
  elsif file.end_with?('.pdf')
    grouped_data[key][:pdf] = PdfParser.new(file).call
  end
end

############################################ GENERATE REPORT ###########################################################
report = ReportGenerator.new(grouped_data)
report.call
report.print_report
############################################ MENU OPTION LOOP ##########################################################

selected_option = 0
exit_option = 3
while selected_option != exit_option
  puts "\n\nSelect Options:"
  puts "1 - check especific month complete report"
  puts '2 - check all months report'
  puts "#{exit_option} - exit"

  selected_option = gets.chomp.to_i

  if selected_option == 1
    puts "\n\nSelect month and year:"
    grouped_data.keys.each_with_index { |key, index| puts "#{index + 1} - #{key}" }
  
    selected_date_option = gets.chomp
    selected_date = grouped_data.keys[selected_date_option.to_i - 1]
  
    puts "\n📅 Complete Report for #{selected_date}:"
  
    entries = (grouped_data[selected_date][:csv] || []) + (grouped_data[selected_date][:pdf] || [])
  
    grouped_by_category = entries.group_by { |e| e[:category] }
  
    grouped_by_category.each do |category, cat_entries|
      puts "\n🔷 Category: #{category.upcase}"
    
      grouped_by_subcategory = cat_entries.group_by { |e| e[:subcategory] }
    
      grouped_by_subcategory.each do |subcategory, sub_entries|
        puts " 🔸 Subcategory: #{subcategory} / #{category.upcase} "
        total = 0.0
    
        sub_entries.sort_by { |entry| Date.strptime(entry[:date], '%d/%m/%Y')   }.each do |entry|
          color = color_for(entry)
          puts "#{color}    • R$ #{entry[:type] == 'credit' ? '+' : '-'} #{'%.2f' % entry[:amount]} - #{entry[:description]} - #{entry[:date]}\e[0m"
          total += entry[:amount]
        end
    
        puts "    🧾 R$ #{'%.2f' % total} as Total for #{subcategory}\n\n"
      end
    end
    report.print_single_month_report(selected_date) # here on this line
  end 

  if selected_option == 2
    report.print_report
  end 
end
