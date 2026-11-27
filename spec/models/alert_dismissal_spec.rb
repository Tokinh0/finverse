require 'rails_helper'

RSpec.describe AlertDismissal do
  it { is_expected.to belong_to(:parsed_transaction).class_name('Transaction') }
  it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }

  it 'allows one dismissal per transaction and kind' do
    transaction = create(:transaction)
    described_class.create!(parsed_transaction: transaction, kind: 'duplicate')

    expect(described_class.new(parsed_transaction: transaction, kind: 'duplicate')).not_to be_valid
    expect(described_class.new(parsed_transaction: transaction, kind: 'new_merchant')).to be_valid
  end

  it 'is removed with its transaction' do
    transaction = create(:transaction)
    described_class.create!(parsed_transaction: transaction, kind: 'duplicate')

    expect { transaction.destroy }.to change(described_class, :count).by(-1)
  end
end
