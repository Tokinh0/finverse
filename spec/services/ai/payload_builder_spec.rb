require 'rails_helper'

RSpec.describe Ai::PayloadBuilder do
  let!(:fallback) { create(:subcategory, :other) }
  let(:bakery) { create(:subcategory, name: 'Padaria', category: create(:category, name: 'Alimentação')) }

  def group(*names, amount: 10)
    transactions = names.map do |name|
      create(:transaction, name: name, amount: amount, subcategory: fallback, categorization_source: 'uncategorized',
                           monthly_statement: create(:monthly_statement, statement_kind: 'checking_account'))
    end
    Suggestions::Candidates::Group.new(merchant_key: Transactions::Merchant.key(transactions.first), transactions: transactions)
  end

  it 'sends subcategories (without the fallback), rules and compact, scrubbed items' do
    create(:keyword, name: 'PADARIA', subcategory: bakery)
    groups = [ group('PIX 123.456.789-09 PADARIA SOL', 'PIX 123.456.789-09 PADARIA SOL') ]

    built = described_class.new(groups, rejected: { groups.first.merchant_key => [ bakery.id ] }).call

    expect(built[:payload][:subcategories]).to eq([ { id: bakery.id, name: 'Alimentação / Padaria', type: 'expense' } ])
    expect(built[:payload][:rules]).to eq([ [ 'PADARIA', bakery.id ] ])
    expect(built[:payload][:items]).to eq([
      { id: 1, name: 'PIX # PADARIA SOL', count: 2, avg_amount: 10.0, type: 'debit', statement: 'checking_account', not: [ bakery.id ] }
    ])
    expect(built[:items]).to eq(1 => groups.first)
    expect(built[:payload].to_json).not_to include('123.456')
  end

  it 'adds a few past examples that share a meaningful word, owner decisions first' do
    create(:transaction, name: 'PADARIA LUA', subcategory: bakery, categorization_source: 'keyword')
    create(:transaction, name: 'PADARIA ESTRELA', subcategory: bakery, categorization_source: 'manual')
    create(:transaction, name: 'PADARIA COMETA', subcategory: bakery, categorization_source: 'manual')
    create(:transaction, name: 'PAGAMENTO LOJA', subcategory: bakery, categorization_source: 'manual') # only a generic word in common

    examples = described_class.new([ group('PAGAMENTO PADARIA SOL') ]).call[:payload][:examples]

    expect(examples).to contain_exactly([ 'PADARIA ESTRELA', bakery.id ], [ 'PADARIA COMETA', bakery.id ])
  end

  it 'omits `not` when nothing was rejected' do
    expect(described_class.new([ group('MERCADO') ]).call[:payload][:items].first).not_to have_key(:not)
  end
end
