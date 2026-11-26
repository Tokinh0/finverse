require 'rails_helper'

RSpec.describe Keyword do
  it { is_expected.to belong_to(:subcategory) }
  it { is_expected.to validate_presence_of(:name) }

  it 'normalizes the name into parsed_name' do
    expect(described_class.new(name: 'mc donalds').parsed_name).to eq('MC_DONALDS')
  end

  it 'rejects the same keyword twice in one subcategory' do
    existing = create(:keyword, name: 'IFOOD')

    expect(build(:keyword, name: 'ifood', subcategory: existing.subcategory)).not_to be_valid
  end

  it 'infers keyword_type for new records without one' do
    expect(described_class.new(name: 'RECEBIMENTO PIX').keyword_type).to eq('credit')
  end

  it 'keeps an explicit keyword_type' do
    expect(described_class.new(name: 'RECEBIMENTO PIX', keyword_type: 'ignored').keyword_type).to eq('ignored')
  end

  it 'delegates category to its subcategory' do
    keyword = build(:keyword)

    expect(keyword.category).to eq(keyword.subcategory.category)
  end
end
