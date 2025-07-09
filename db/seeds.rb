require 'json'
include StringUtils
include JsonUtils

# Load and prepare data
seed_data = load_default_data
CATEGORIES_WITH_KEYWORDS = seed_data['categories_with_keywords'] || {}
DEBIT_KEYWORDS = (seed_data['debit_keywords'] || []).map { |k| default_string_parse(k) }
CREDIT_KEYWORDS = (seed_data['credit_keywords'] || []).map { |k| default_string_parse(k) }
IGNORED_KEYWORDS = (seed_data['ignored_keywords'] || []).map { |k| default_string_parse(k) }

def detect_keyword_type(parsed_keyword)
  return :debit   if DEBIT_KEYWORDS.include?(parsed_keyword)
  return :credit  if CREDIT_KEYWORDS.include?(parsed_keyword)
  return :ignored if IGNORED_KEYWORDS.include?(parsed_keyword)
  :unknown
end

# Process data
CATEGORIES_WITH_KEYWORDS.each do |category_key, subcategory_mappings|
  parsed_category_name = default_string_parse(category_key)
  category = Category.find_or_initialize_by(parsed_name: parsed_category_name)
  category.name = category_key
  category.save!

  next unless subcategory_mappings.is_a?(Array) && subcategory_mappings.first.is_a?(Hash)

  subcategory_mappings.first.each do |subcategory_name, keywords|
    parsed_subcategory_name = default_string_parse(subcategory_name)
    subcategory = Subcategory.find_or_initialize_by(parsed_name: parsed_subcategory_name, category: category)
    subcategory.name = subcategory_name
    subcategory.save!

    (keywords || []).compact.each do |keyword_name|
      parsed_keyword = default_string_parse(keyword_name)
      keyword = Keyword.find_or_initialize_by(parsed_name: parsed_keyword, subcategory: subcategory)
      keyword.name = keyword_name
      keyword.save!
    rescue ActiveRecord::RecordInvalid => e
      puts "⚠️ Skipping invalid keyword '#{keyword_name}': #{e.record.errors.full_messages.join(', ')}"
    end
  end
rescue ActiveRecord::RecordInvalid => e
  puts "⚠️ Skipping invalid subcategory/category: #{e.record.inspect}"
end
