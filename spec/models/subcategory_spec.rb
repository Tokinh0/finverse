require 'rails_helper'

RSpec.describe Subcategory do
  it { is_expected.to belong_to(:category) }
  it { is_expected.to have_many(:transactions) }
  it { is_expected.to have_many(:keywords).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:name) }

  it 'allows the same name in different categories' do
    create(:subcategory, name: 'Outros')

    expect(build(:subcategory, name: 'Outros')).to be_valid
  end

  it 'rejects the same name twice in one category' do
    existing = create(:subcategory, name: 'Food')

    expect(build(:subcategory, name: 'food', category: existing.category)).not_to be_valid
  end

  describe '.other_subcategory' do
    it 'returns the "Outros" subcategory of the "Outros" category' do
      other = create(:subcategory, :other)

      expect(described_class.other_subcategory).to eq(other)
    end

    it 'raises when the fallback subcategory is missing' do
      create(:category, :other)

      expect { described_class.other_subcategory }.to raise_error(RuntimeError, /Subcategory/)
    end
  end
end
