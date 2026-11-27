require 'rails_helper'

RSpec.describe Suggestions::Enqueue do
  let!(:fallback) { create(:subcategory, :other) }
  let(:statement) { create(:monthly_statement) }

  it 'starts a run when the statement has uncategorized transactions' do
    create(:transaction, monthly_statement: statement, subcategory: fallback, categorization_source: 'uncategorized')

    run = nil
    expect { run = described_class.call(statement) }.to have_enqueued_job(GenerateSuggestionsJob)
    expect(run).to have_attributes(monthly_statement: statement, status: 'queued')
  end

  it 'does nothing when everything was categorized' do
    create(:transaction, monthly_statement: statement, categorization_source: 'keyword')

    expect(described_class.call(statement)).to be_nil
  end

  it 'does not start a second run while one is in progress' do
    create(:transaction, subcategory: fallback, categorization_source: 'uncategorized')
    create(:suggestion_run, status: 'running')

    expect(described_class.call).to be_nil
  end

  it 'ignores transactions marked "no idea"' do
    create(:transaction, monthly_statement: statement, subcategory: fallback, categorization_source: 'uncategorized',
                         unknown_marked_at: Time.current)

    expect(described_class.call(statement)).to be_nil
  end
end
