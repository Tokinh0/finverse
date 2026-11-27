require 'rails_helper'

RSpec.describe Suggestions::Candidates do
  let!(:fallback) { create(:subcategory, :other) }
  let(:statement) { create(:monthly_statement, statement_kind: 'credit_card') }

  def uncategorized(name, **attrs)
    create(:transaction, name: name, subcategory: fallback, monthly_statement: statement, categorization_source: 'uncategorized', **attrs)
  end

  it 'groups uncategorized transactions by merchant, biggest first' do
    a = uncategorized('PADARIA EXEMPLO 123', amount: 10)
    b = uncategorized('PADARIA EXEMPLO 456', amount: 20)
    c = uncategorized('MERCADO')
    create(:transaction, name: 'IFOOD', categorization_source: 'keyword')

    groups = described_class.call

    expect(groups.map(&:merchant_key)).to eq(%w[PADARIA_EXEMPLO MERCADO])
    expect(groups.first.transactions).to eq([ a, b ])
    expect(groups.first).to have_attributes(average_amount: 15.0, transaction_type: 'debit', statement_kinds: [ 'credit_card' ])
    expect(groups.last.transactions).to eq([ c ])
  end

  it 'skips transactions that already have a pending suggestion, but not rejected ones' do
    pending = uncategorized('PADARIA')
    rejected = uncategorized('MERCADO')
    create(:category_suggestion, parsed_transaction: pending)
    create(:category_suggestion, parsed_transaction: rejected, status: 'rejected')

    expect(described_class.call.flat_map(&:transactions)).to eq([ rejected ])
  end

  it 'can be limited to one statement' do
    mine = uncategorized('PADARIA')
    create(:transaction, name: 'OUTRA', subcategory: fallback, categorization_source: 'uncategorized')

    expect(described_class.call(statement).flat_map(&:transactions)).to eq([ mine ])
  end
end
