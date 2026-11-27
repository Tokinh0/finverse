require 'rails_helper'

RSpec.describe Suggestions::Generate do
  let!(:fallback) { create(:subcategory, :other) }
  let(:bakery) { create(:subcategory, name: 'Padaria') }
  let(:market) { create(:subcategory, name: 'Mercado') }
  let(:statement) { create(:monthly_statement) }
  let(:run) { create(:suggestion_run, monthly_statement: statement) }

  def uncategorized(name)
    create(:transaction, name: name, subcategory: fallback, monthly_statement: statement, categorization_source: 'uncategorized')
  end

  def with_key
    AppSetting.current.update!(claude_api_key: 'sk-ant-test')
    allow_any_instance_of(Ai::Client).to receive(:initialize).and_wrap_original { |m, **kw| m.call(**kw, max_retries: 0) }
  end

  it 'sends only what keyword rules and history could not place, in one request' do
    with_key
    create(:transaction, name: 'PADARIA SOL', subcategory: bakery, categorization_source: 'manual') # history
    create(:transaction, name: 'IFOOD', subcategory: market, monthly_statement: statement, categorization_source: 'keyword')
    from_history = uncategorized('PADARIA SOL')
    for_claude = [ uncategorized('MERCADO LUA 1'), uncategorized('MERCADO LUA 2') ]
    stub = stub_claude_message({ category_suggestions: [ { item_id: 1, subcategory_id: market.id, confidence: 0.8, reason: 'Market' } ] })

    described_class.call(run)

    expect(stub).to have_been_requested.once
    items = JSON.parse(claude_request_body['messages'].first['content'])['items']
    expect(items.map { _1['name'] }).to eq([ 'MERCADO LUA 1' ])
    expect(from_history.pending_category_suggestion).to have_attributes(origin: 'history', subcategory: bakery)
    expect(for_claude.map { _1.pending_category_suggestion.slice(:origin, :subcategory_id) })
      .to all(eq('origin' => 'ai', 'subcategory_id' => market.id))
    expect(run.reload).to have_attributes(
      status: 'succeeded', history_suggestions_count: 1, ai_suggestions_count: 2, ai_groups_sent: 1,
      ai_requests_count: 1, input_tokens: 120, output_tokens: 40, model: 'claude-haiku-5-5'
    )
  end

  it 'makes only history suggestions without a key' do
    create(:transaction, name: 'PADARIA SOL', subcategory: bakery, categorization_source: 'manual')
    uncategorized('PADARIA SOL')
    uncategorized('NOVO')

    described_class.call(run)

    expect(WebMock).not_to have_requested(:post, %r{api.anthropic.com})
    expect(CategorySuggestion.pluck(:origin)).to eq([ 'history' ])
    expect(run.reload).to be_succeeded
  end

  it 'splits a large backlog into batches' do
    with_key
    stub_const("#{described_class}::MAX_GROUPS_PER_REQUEST", 2)
    3.times { |i| uncategorized("LOJA #{%w[A B C][i]}") }
    stub = stub_claude_message({ category_suggestions: [] })

    described_class.call(run)

    expect(stub).to have_been_requested.twice
    expect(run.reload).to have_attributes(ai_requests_count: 2, ai_groups_sent: 3)
  end

  it 'marks the run failed on a non-retryable error, keeping history suggestions' do
    with_key
    create(:transaction, name: 'PADARIA SOL', subcategory: bakery, categorization_source: 'manual')
    uncategorized('PADARIA SOL')
    uncategorized('NOVO')
    stub_request(:post, %r{api.anthropic.com/v1/messages}).to_return(status: 401, body: claude_error_body('authentication_error').to_json,
                                                                     headers: { 'Content-Type' => 'application/json' })

    described_class.call(run)

    expect(run.reload).to have_attributes(status: 'failed', error_code: 'invalid_key', error_message: /rejected/)
    expect(CategorySuggestion.count).to eq(1)
  end

  it 're-raises retryable errors for the job and leaves the run queued' do
    with_key
    uncategorized('NOVO')
    stub_request(:post, %r{api.anthropic.com/v1/messages}).to_return(status: 429, body: claude_error_body('rate_limit_error').to_json,
                                                                     headers: { 'Content-Type' => 'application/json' })

    expect { described_class.call(run) }.to raise_error(Ai::Client::RetryableError)
    expect(run.reload).to have_attributes(status: 'queued', error_code: 'rate_limited')
  end

  it 'does not suggest again for transactions that already have a pending suggestion' do
    with_key
    create(:category_suggestion, parsed_transaction: uncategorized('NOVO'))
    stub = stub_claude_message({ category_suggestions: [] })

    described_class.call(run)

    expect(stub).not_to have_been_requested
  end

  it 'saves rule suggestions from the same Claude request, skipping useless ones' do
    with_key
    uncategorized('MERCADO LUA 1')
    uncategorized('MERCADO LUA 2')
    stub = stub_claude_message({ category_suggestions: [], rule_suggestions: [
      { action: 'create', keyword_id: nil, keyword: 'MERCADO LUA', subcategory_id: market.id, confidence: 0.85, reason: 'Recurs' },
      { action: 'create', keyword_id: nil, keyword: 'NADA DISSO', subcategory_id: market.id, confidence: 0.85, reason: 'No match' }
    ] })

    described_class.call(run)

    expect(stub).to have_been_requested.once
    expect(RuleSuggestion.sole).to have_attributes(origin: 'ai', parsed_name: 'MERCADO_LUA', subcategory: market, suggestion_run: run)
    expect(run.reload.rule_suggestions_count).to eq(1)
  end

  it 'makes local rule suggestions even without a key' do
    3.times do |i|
      transaction = create(:transaction, name: "TAXI AMIGO #{i}", subcategory: market, categorization_source: 'manual')
      create(:categorization_event, parsed_transaction: transaction, to_subcategory: market)
    end
    uncategorized('NOVO')

    described_class.call(run)

    expect(RuleSuggestion.sole).to have_attributes(origin: 'local', parsed_name: 'TAXI_AMIGO')
    expect(run.reload.rule_suggestions_count).to eq(1)
  end
end
