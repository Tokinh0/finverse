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
end
