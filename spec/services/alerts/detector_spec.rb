require 'rails_helper'

RSpec.describe Alerts::Detector do
  let!(:fallback) { create(:subcategory, :other) }
  let(:food) { create(:subcategory, name: 'Food', subcategory_type: 'expense') }
  let(:savings) { create(:subcategory, name: 'Poupanca', subcategory_type: 'investment') }

  def charge(name, amount, date, subcategory: food, type: 'debit')
    create(:transaction, name: name, amount: amount, transaction_date: date, subcategory: subcategory, transaction_type: type)
  end

  def kinds(month = '2025-07')
    described_class.call(month: month).map { |a| [ a.kind, a.transaction.name ] }
  end

  describe '.merchant_key' do
    it 'ignores digits so the same payee with different ids matches' do
      a = build(:transaction, name: 'PAGAMENTO PIX 123 JOAO')
      b = build(:transaction, name: 'PAGAMENTO PIX 98765 JOAO')

      expect(described_class.merchant_key(a)).to eq('PAGAMENTO_PIX_JOAO')
      expect(described_class.merchant_key(b)).to eq(described_class.merchant_key(a))
    end
  end

  it 'flags the second of two identical charges on the same day' do
    charge('NETFLIX', 55.9, Date.new(2025, 7, 10))
    second = charge('NETFLIX', 55.9, Date.new(2025, 7, 10))
    charge('NETFLIX', 55.9, Date.new(2025, 7, 12)) # different day
    charge('NETFLIX', 10, Date.new(2025, 7, 10))   # different amount

    alerts = described_class.call(month: '2025-07').select { |a| a.kind == 'duplicate' }

    expect(alerts.map(&:transaction)).to eq([ second ])
    expect(alerts.first.details).to include(related_transaction_id: kind_of(Integer))
    expect(alerts.first.message).to eq('Same merchant and amount as a charge on 07/10/2025')
  end

  it 'writes alert messages and dates in Portuguese when that is the language' do
    charge('NETFLIX', 55.9, Date.new(2025, 7, 10))
    charge('NETFLIX', 55.9, Date.new(2025, 7, 10))

    message = I18n.with_locale(:'pt-BR') { described_class.call(month: '2025-07').find { _1.kind == 'duplicate' }.message }

    expect(message).to eq('Mesmo estabelecimento e valor de uma cobrança em 10/07/2025')
  end

  it 'flags uncategorized merchants never seen before, from R$ 100' do
    charge('OLD SHOP', 20, Date.new(2025, 5, 1), subcategory: fallback)
    charge('OLD SHOP', 300, Date.new(2025, 7, 2), subcategory: fallback)       # seen before
    charge('BRAND NEW LTDA', 150, Date.new(2025, 7, 3), subcategory: fallback) # new
    charge('BRAND NEW LTDA', 150, Date.new(2025, 7, 20), subcategory: fallback) # only first is flagged
    charge('TINY NEW', 30, Date.new(2025, 7, 4), subcategory: fallback)        # too small
    charge('NEW RESTAURANT', 500, Date.new(2025, 7, 5))                        # categorized by a keyword

    expect(kinds.select { |k, _| k == 'new_merchant' }).to eq([ [ 'new_merchant', 'BRAND NEW LTDA' ] ])
  end

  it 'skips new merchant alerts when there is no history yet' do
    charge('BRAND NEW LTDA', 150, Date.new(2025, 7, 3), subcategory: fallback)

    expect(kinds).to be_empty
  end

  it 'flags a recurring monthly charge whose amount changed' do
    charge('SPOTIFY', 21.9, Date.new(2025, 5, 5))
    charge('SPOTIFY', 21.9, Date.new(2025, 6, 5))
    raised = charge('SPOTIFY', 23.9, Date.new(2025, 7, 5))
    charge('UNSTABLE', 10, Date.new(2025, 5, 5))
    charge('UNSTABLE', 30, Date.new(2025, 6, 5))
    charge('UNSTABLE', 50, Date.new(2025, 7, 5))

    alert = described_class.call(month: '2025-07').find { |a| a.kind == 'amount_changed' }

    expect(alert.transaction).to eq(raised)
    expect(alert.message).to eq('Recurring charge changed from R$ 21,90 to R$ 23,90')
    expect(alert.details).to eq(expected_amount: 21.9)
  end

  it 'flags amounts far above the median of an expense subcategory' do
    [ 40, 50, 55, 60, 45 ].each_with_index { |amount, i| charge("MEAL #{i}", amount, Date.new(2025, 6, i + 1)) }
    big = charge('MEAL BIG', 400, Date.new(2025, 7, 9))
    charge('MEAL OK', 120, Date.new(2025, 7, 10))
    5.times { |i| charge("APLIC #{i}", 50, Date.new(2025, 6, i + 1), subcategory: savings) }
    charge('APLIC BIG', 5000, Date.new(2025, 7, 9), subcategory: savings) # investments are not spending

    alerts = described_class.call(month: '2025-07').select { |a| a.kind == 'unusual_amount' }

    expect(alerts.map(&:transaction)).to eq([ big ])
    expect(alerts.first.message).to eq('8.0× the usual R$ 50,00 for Food')
  end

  it 'ignores credits' do
    charge('X', 99, Date.new(2025, 7, 1), type: 'credit')
    charge('X', 99, Date.new(2025, 7, 1), type: 'credit')

    expect(kinds).to be_empty
  end

  it 'hides dismissed alerts unless asked' do
    charge('NETFLIX', 55.9, Date.new(2025, 7, 10))
    second = charge('NETFLIX', 55.9, Date.new(2025, 7, 10))
    AlertDismissal.create!(parsed_transaction: second, kind: 'duplicate')

    expect(described_class.call(month: '2025-07')).to be_empty
    expect(described_class.call(month: '2025-07', include_dismissed: 'true').map(&:dismissed)).to eq([ true ])
  end

  it 'defaults to the latest month with debits' do
    charge('A', 10, Date.new(2025, 3, 1))
    charge('B', 10, Date.new(2025, 4, 30))

    expect(described_class.new.month).to eq(Date.new(2025, 4, 1))
    expect(described_class.new(month: 'nope').month).to eq(Date.new(2025, 4, 1))
  end

  it 'returns nothing without transactions' do
    expect(described_class.call).to eq([])
  end
end
