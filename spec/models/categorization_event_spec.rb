require 'rails_helper'

RSpec.describe CategorizationEvent do
  subject { described_class.new(parsed_transaction: create(:transaction), from_source: 'keyword', to_source: 'manual', merchant_key: 'X') }

  it { is_expected.to belong_to(:parsed_transaction).class_name('Transaction') }
  it { is_expected.to belong_to(:overridden_keyword).class_name('Keyword').optional }
  it { is_expected.to validate_inclusion_of(:from_source).in_array(Transaction.categorization_sources.keys) }
  it { is_expected.to validate_inclusion_of(:to_source).in_array(Transaction.categorization_sources.keys) }
  it { is_expected.to validate_presence_of(:merchant_key) }

  it 'is removed with its transaction' do
    subject.save!

    expect { subject.parsed_transaction.destroy }.to change(described_class, :count).by(-1)
  end
end
