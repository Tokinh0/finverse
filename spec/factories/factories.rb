FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Account #{n}" }
  end

  factory :profile do
    account { Account.default }
    sequence(:name) { |n| "Profile #{n}" }
    locale { 'en' }

    trait :with_password do
      password { 'secret123' }
    end
  end

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

  factory :suggestion_run do
    status { 'queued' }
  end

  factory :category_suggestion do
    association :parsed_transaction, factory: :transaction
    subcategory
    origin { 'ai' }
    confidence { 0.8 }
    status { 'pending' }
  end

  factory :categorization_event do
    association :parsed_transaction, factory: :transaction
    from_source { 'keyword' }
    to_source { 'manual' }
    merchant_key { Transactions::Merchant.key(parsed_transaction) }
    to_subcategory { parsed_transaction.subcategory }
  end

  factory :rule_suggestion do
    action { 'create' }
    sequence(:name) { |n| "RULE #{n}" }
    subcategory
    origin { 'ai' }
    confidence { 0.8 }
    status { 'pending' }
  end
end
