require 'rails_helper'

RSpec.describe GenerateSuggestionsJob do
  let(:run) { create(:suggestion_run) }

  it 'runs the pipeline for the run' do
    allow(Suggestions::Generate).to receive(:call)

    described_class.perform_now(run.id)

    expect(Suggestions::Generate).to have_received(:call).with(run)
  end

  it 'retries retryable errors and marks the run failed after the last attempt' do
    allow(Suggestions::Generate).to receive(:call).and_raise(Ai::Client::RetryableError.new('rate_limited'))

    job = described_class.new(run.id)
    job.exception_executions = { '[Ai::Client::RetryableError]' => 3 }
    job.perform_now

    expect(run.reload).to have_attributes(status: 'failed', error_code: 'rate_limited', error_message: /rate limit was reached/)
  end

  it 'schedules a retry before the last attempt' do
    allow(Suggestions::Generate).to receive(:call).and_raise(Ai::Client::RetryableError.new('timeout'))

    expect { described_class.perform_now(run.id) }.to have_enqueued_job(described_class).with(run.id)
  end

  it "works as the run's profile, whoever is current when it runs" do
    other = create(:profile, locale: 'pt-BR')
    their_run = as_profile(other) { create(:suggestion_run) }
    seen = nil
    allow(Suggestions::Generate).to receive(:call) { seen = [ Current.profile, SuggestionRun.all.to_a ] }

    Current.profile = nil
    described_class.perform_now(their_run.id)

    expect(seen).to eq([ other, [ their_run ] ])
  end
end
