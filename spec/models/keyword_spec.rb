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

  describe 'amount range' do
    it 'applies only inside its range, bounds included, and never without an amount' do
      keyword = build(:keyword, min_amount: 100, max_amount: 200)

      expect([ 99.99, 100, 150, 200, 200.01 ].map { keyword.applies_to_amount?(_1) }).to eq([ false, true, true, true, false ])
      expect(keyword.applies_to_amount?(-150)).to be(true) # absolute value
      expect(keyword.applies_to_amount?(nil)).to be(false)
      expect(build(:keyword).applies_to_amount?(nil)).to be(true)
    end

    it 'validates the bounds' do
      expect(build(:keyword, min_amount: 200, max_amount: 100)).not_to be_valid
      expect(build(:keyword, min_amount: -1)).not_to be_valid
    end

    it 'allows the same keyword in one subcategory with different ranges' do
      first = create(:keyword, name: 'AMAZON', max_amount: 99.99)

      expect(build(:keyword, name: 'AMAZON', subcategory: first.subcategory, min_amount: 100)).to be_valid
      expect(build(:keyword, name: 'AMAZON', subcategory: first.subcategory, max_amount: 99.99)).not_to be_valid
    end
  end
end
