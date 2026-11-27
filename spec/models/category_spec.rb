require 'rails_helper'

RSpec.describe Category do
  it { is_expected.to have_many(:subcategories).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:name) }

  it 'normalizes the name into parsed_name' do
    expect(described_class.new(name: ' Contas  Fixas ').parsed_name).to eq('CONTAS_FIXAS')
  end

  it 'keeps parsed_name in sync when the name is updated' do
    category = create(:category, name: 'Lazer')
    category.update!(name: 'Viagem')

    expect(category.reload.parsed_name).to eq('VIAGEM')
  end

  it 'rejects a duplicated parsed_name' do
    create(:category, name: 'Lazer')

    expect(described_class.new(name: 'lazer')).not_to be_valid
  end

  describe '.other_category' do
    it 'returns the "Outros" category' do
      other = create(:category, :other)
      create(:category)

      expect(described_class.other_category).to eq(other)
    end
  end

  describe 'destroy' do
    it 'moves the transactions of its subcategories to the fallback' do
      fallback = create(:subcategory, :other)
      transaction = create(:transaction, subcategory: create(:subcategory, name: 'Cinema'))

      expect(transaction.subcategory.category.destroy).to be_truthy
      expect(transaction.reload.subcategory).to eq(fallback)
    end

    it 'refuses to delete the "Outros" fallback category' do
      category = create(:category, :other)

      expect(category.destroy).to be(false)
      expect(category.errors[:base]).to include(/cannot be deleted/)
    end
  end
end
