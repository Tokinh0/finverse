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

  describe 'destroy' do
    let!(:fallback) { create(:subcategory, :other) }

    it 'moves its transactions to the "Outros" fallback and removes its keywords' do
      food = create(:subcategory, name: 'Food')
      transaction = create(:transaction, subcategory: food)
      create(:keyword, subcategory: food)

      expect(food.destroy).to be_truthy
      expect(transaction.reload.subcategory).to eq(fallback)
      expect(Keyword.count).to eq(0)
    end

    it 'refuses to delete the fallback subcategory' do
      expect(fallback.destroy).to be(false)
      expect(fallback.errors[:base]).to include(/cannot be deleted/)
      expect(described_class.exists?(fallback.id)).to be(true)
    end
  end

  describe '#fallback?' do
    it 'is true only for "Outros" inside the "Outros" category' do
      expect(build(:subcategory, :other)).to be_fallback
      expect(build(:subcategory, name: 'Outros')).not_to be_fallback
    end
  end
end
