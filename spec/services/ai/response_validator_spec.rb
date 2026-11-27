require 'rails_helper'

RSpec.describe Ai::ResponseValidator do
  def validate(entries, excluded: {})
    described_class.call({ 'category_suggestions' => entries }, item_ids: [ 1, 2, 3 ], subcategory_ids: [ 10, 11 ], excluded: excluded)
  end

  it 'keeps valid suggestions' do
    result = validate([ { 'item_id' => 1, 'subcategory_id' => 10, 'confidence' => 0.876, 'reason' => ' Bakery ' } ])

    expect(result.category_suggestions).to eq([ { item_id: 1, subcategory_id: 10, confidence: 0.88, reason: 'Bakery' } ])
    expect(result.dropped).to eq(0)
  end

  it 'drops unknown items and subcategories, bad confidences, duplicates, rejected picks and junk' do
    result = validate([
      { 'item_id' => 9, 'subcategory_id' => 10, 'confidence' => 0.9 },
      { 'item_id' => 1, 'subcategory_id' => 99, 'confidence' => 0.9 },
      { 'item_id' => 1, 'subcategory_id' => 10, 'confidence' => 1.5 },
      { 'item_id' => '2', 'subcategory_id' => 10, 'confidence' => 0.9 },
      { 'item_id' => 3, 'subcategory_id' => 11, 'confidence' => 0.9 },
      'nonsense',
      { 'item_id' => 2, 'subcategory_id' => 11, 'confidence' => 0.7 },
      { 'item_id' => 2, 'subcategory_id' => 10, 'confidence' => 0.6 }
    ], excluded: { 3 => [ 11 ] })

    expect(result.category_suggestions.map { _1.values_at(:item_id, :subcategory_id) }).to eq([ [ 2, 11 ] ])
    expect(result.dropped).to eq(7)
  end

  it 'returns nothing for an answer of the wrong shape' do
    expect(described_class.call([], item_ids: [ 1 ], subcategory_ids: [ 1 ]).category_suggestions).to eq([])
  end
end
