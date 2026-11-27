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
    rule = create(:keyword, name: 'PADARIA', subcategory: bakery)
    groups = [ group('PIX 123.456.789-09 PADARIA SOL', 'PIX 123.456.789-09 PADARIA SOL') ]

    built = described_class.new(groups, rejected: { groups.first.merchant_key => [ bakery.id ] }).call

    expect(built[:payload][:subcategories]).to eq([ { id: bakery.id, name: 'Alimentação / Padaria', type: 'expense' } ])
    expect(built[:payload][:rules]).to eq([ [ rule.id, 'PADARIA', bakery.id ] ])
    expect(built[:payload][:rule_issues]).to eq([])
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

  it 'adds rule problems, repeated corrections and rejected rule changes' do
    overridden = create(:keyword, name: 'SOL', subcategory: bakery)
    market = create(:subcategory, name: 'Mercado')
    3.times do
      transaction = create(:transaction, name: 'SOL', subcategory: market, categorization_source: 'manual')
      create(:categorization_event, parsed_transaction: transaction, overridden_keyword: overridden, to_subcategory: market)
    end
    create(:rule_suggestion, action: 'create', name: 'LUA', subcategory: market, status: 'rejected', decided_at: Time.current)

    payload = described_class.new([ group('MERCADO') ]).call[:payload]

    expect(payload[:rule_issues]).to eq([ [ overridden.id, 0, 3, market.id, 'overridden' ] ])
    expect(payload[:corrections]).to eq([ [ 'SOL', market.id, 3 ] ])
    expect(payload[:rejected_rules]).to eq([ [ 'create', 'LUA', market.id ] ])
  end

  it "sends the owner's notes, scrubbed, those about the batch's merchants first" do
    market = create(:subcategory, name: 'Mercado')
    noted = lambda do |name, note, subcategory|
      transaction = create(:transaction, name: name, subcategory: subcategory, categorization_source: 'manual')
      create(:categorization_event, parsed_transaction: transaction, to_subcategory: subcategory, note: note)
    end
    noted.call('LOJA ANTIGA', 'old note', market)
    noted.call('PADARIA SOL', 'Paid with CPF 123.456.789-09, it is my bakery', bakery)
    noted.call('OUTRA COISA', '', market)

    notes = described_class.new([ group('PADARIA SOL') ]).call[:payload][:notes]

    expect(notes).to eq([ [ 'PADARIA_SOL', bakery.id, 'Paid with CPF #, it is my bakery' ], [ 'LOJA_ANTIGA', market.id, 'old note' ] ])
  end
end
