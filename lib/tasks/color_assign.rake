# lib/tasks/color_assign.rake
# rake db:assign_color_codes

namespace :db do
  desc "Assign light‐green tones to income categories and dark tones to expense categories"
  task assign_color_codes: :environment do
    # 1) Define which categories are “income”
    income_names = %w[Ganhos Investimento].map(&:downcase)

    # 2) Palettes
    income_palette = [
      "#D4EFDF", # very light green
      "#A9DFBF",
      "#7DCEA0",
      "#52BE80"
    ]

    expense_palette = [
      "#1B2631", # charcoal
      "#154360", # dark blue
      "#1C2833",
      "#641E16", # burgundy
      "#78281F",
      "#424949",
      "#512E5F",
      "#2E4053"
    ]

    Category.find_each do |category|
      theme = income_names.include?(category.name.downcase) ? :income : :expense
      palette = theme == :income ? income_palette : expense_palette

      # build the ordered list: first the category itself, then its subcategories
      items = [category] + category.subcategories.to_a

      items.each_with_index do |item, idx|
        color = palette[idx % palette.length]
        item.update!(color_code: color)
      end

      puts "→ #{theme.to_s.upcase}: assigned #{items.size} colors from #{palette.first}(…) to “#{category.name}” and its #{category.subcategories.count} subcategories"
    end

    puts "✅ Done assigning color_codes!"
  end
end
