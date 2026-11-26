FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    color_code { '#123456' }

    trait :other do
      name { 'Outros' }
    end
  end

  factory :subcategory do
    category
    sequence(:name) { |n| "Subcategory #{n}" }
    color_code { '#654321' }
    subcategory_type { 'expense' }

    trait :other do
      name { 'Outros' }
      association :category, factory: %i[category other]
    end
  end

  factory :keyword do
    subcategory
    sequence(:name) { |n| "KEYWORD #{n}" }
    keyword_type { 'debit' }
  end

  factory :monthly_statement do
    status { 'unprocessed' }
  end

  factory :transaction do
    monthly_statement
    subcategory
    sequence(:name) { |n| "TRANSACTION #{n}" }
    amount { 10.5 }
    transaction_date { Date.new(2025, 1, 15) }
    transaction_type { 'debit' }
  end

  factory :summary_line do
    monthly_statement
    status { 'processed' }
    content { '[]' }
  end

  factory :asset do
    asset_type { 'acoes_nacionais' }
    sequence(:ticker) { |n| "TICK#{n}" }
    description { 'An asset' }
    current_value { 100 }
    rating { 3 }
    quantity { 1 }
    color_code { '#abcdef' }
  end
end
