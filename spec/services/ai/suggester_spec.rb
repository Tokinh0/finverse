require 'rails_helper'

RSpec.describe Ai::Suggester do
  let!(:fallback) { create(:subcategory, :other) }
  let(:bakery) { create(:subcategory, name: 'Padaria') }
  let(:client) { Ai::Client.new(api_key: 'sk-ant-test', model: 'claude-haiku-5-5', max_retries: 0) }
  let(:group) do
    transaction = create(:transaction, name: 'PADARIA SOL', subcategory: fallback, categorization_source: 'uncategorized')
    Suggestions::Candidates::Group.new(merchant_key: 'PADARIA_SOL', transactions: [ transaction ])
  end

  it 'asks for structured JSON in one request and maps the answer back to the groups' do
    stub_claude_message({
      category_suggestions: [ { item_id: 1, subcategory_id: bakery.id, confidence: 0.9, reason: 'Bakery' } ],
      rule_suggestions: [ { action: 'create', keyword_id: nil, keyword: 'PADARIA', subcategory_id: bakery.id, confidence: 0.8, reason: 'Recurs' } ]
    })

    result = described_class.new(client).call([ group ])

    body = claude_request_body
    expect(body).to include('model' => 'claude-haiku-5-5', 'max_tokens' => 16_000)
    expect(body['output_config']).to include('effort' => 'low', 'format' => a_hash_including('type' => 'json_schema'))
    expect(body['system']).to include('categorize bank transactions', "`notes` are the owner's own explanations")
    expect(JSON.parse(body['messages'].first['content'])['items'].first).to include('id' => 1, 'name' => 'PADARIA SOL')
    expect(result.suggestions.sole).to have_attributes(group: group, subcategory_id: bakery.id, confidence: 0.9, reason: 'Bakery')
    expect(result.rule_suggestions).to eq([ { action: 'create', keyword_id: nil, keyword: 'PADARIA', subcategory_id: bakery.id,
                                               confidence: 0.8, reason: 'Recurs' } ])
    expect(body['output_config']['format']['schema']['required']).to eq(%w[category_suggestions rule_suggestions])
    expect(result).to have_attributes(dropped: 0, input_tokens: 120, output_tokens: 40)
  end

  it 'never lets Claude pick the fallback or a rejected subcategory' do
    stub_claude_message({ category_suggestions: [
      { item_id: 1, subcategory_id: fallback.id, confidence: 0.9, reason: '' },
      { item_id: 1, subcategory_id: bakery.id, confidence: 0.9, reason: '' }
    ] })

    result = described_class.new(client).call([ group ], rejected: { 'PADARIA_SOL' => [ bakery.id ] })

    expect(result.suggestions).to be_empty
    expect(result.dropped).to eq(2)
  end

  it 'raises a clear error on a refusal, a cut-off answer or invalid JSON' do
    { [ '{}', 'refusal' ] => 'refused', [ '{"category', 'max_tokens' ] => 'bad_response', [ 'not json', 'end_turn' ] => 'bad_response' }
      .each do |(text, stop_reason), code|
        stub_claude_message(text, stop_reason: stop_reason)
        expect { described_class.new(client).call([ group ]) }.to raise_error(Ai::Client::Error) { expect(_1.code).to eq(code) }
      end
  end
end
