require 'rails_helper'

RSpec.describe Profiles::DefaultData do
  it 'creates categories, subcategories with type and color, and keyword rules' do
    described_class.apply

    salary = Subcategory.find_by(parsed_name: 'SALARIO')
    expect(salary).to have_attributes(subcategory_type: 'gain', color_code: '#A9DFBF')
    expect(salary.category).to have_attributes(name: 'Ganhos', color_code: '#D4EFDF')
    expect(salary.keywords.pluck(:parsed_name)).to eq([ 'SALARIO' ])
    expect(Subcategory.find_by(parsed_name: 'FOOD').subcategory_type).to eq('expense')
    expect(Keyword.find_by(parsed_name: 'IFOOD').keyword_type).to eq('debit')
  end

  it 'always creates the Outros fallback' do
    described_class.apply('categories' => [ { 'name' => 'Lazer' } ])

    expect(Subcategory.other_subcategory.category.name).to eq('Outros')
  end

  it "keeps what exists and doesn't duplicate on a second run" do
    described_class.apply
    Subcategory.find_by(parsed_name: 'FOOD').update!(color_code: '#000000')

    expect { described_class.apply }.not_to change(Keyword, :count)
    expect(Subcategory.find_by(parsed_name: 'FOOD').color_code).to eq('#000000')
  end

  it 'refuses a file without categories' do
    expect { described_class.apply({}) }.to raise_error(ArgumentError, /categories/)
  end

  it 'ships generic defaults in db/seed_data/defaults.jsonc' do
    path = Rails.root.join('db/seed_data/defaults.jsonc')
    data = JSON.parse(File.readlines(path).reject { _1.strip.start_with?('//') }.join)

    described_class.apply(data)

    expect(Category.count).to eq(data['categories'].size)
    expect(Subcategory.where.not(subcategory_type: Subcategory.subcategory_types.keys)).not_to exist
    # Public repo: no CPF/CNPJ-like numbers in the shipped keywords.
    expect(Keyword.pluck(:name).grep(/\d{6,}/)).to be_empty
    expect(%w[debit_keywords credit_keywords ignored_keywords].map { data[_1] }).to all(be_present)
  end
end
