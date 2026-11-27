require 'rails_helper'

RSpec.describe Ai::Client do
  subject(:client) { described_class.new(api_key: 'sk-ant-test-key', model: 'claude-haiku-5-5', max_retries: 0) }

  it 'builds a client from the saved settings' do
    AppSetting.current.update!(claude_api_key: 'sk-ant-saved', claude_model: 'claude-sonnet-5-5')

    expect(described_class.for.model).to eq('claude-sonnet-5-5')
  end

  it 'refuses to build a client without a key' do
    expect { described_class.for }.to raise_error(described_class::Error) { |e| expect(e.code).to eq('not_configured') }
  end

  it 'verifies a key with one models call' do
    stub = stub_claude_models

    expect(client.verify!).to be(true)
    expect(stub.with(headers: { 'Authorization' => 'Bearer sk-ant-test-key' })).to have_been_requested.once
  end

  {
    401 => %w[authentication_error invalid_key],
    402 => %w[billing_error billing],
    429 => %w[rate_limit_error rate_limited],
    500 => %w[api_error unavailable],
    529 => %w[overloaded_error unavailable],
    400 => %w[invalid_request_error bad_request]
  }.each do |status, (type, code)|
    it "maps HTTP #{status} to #{code}" do
      stub_claude_models(status: status, body: claude_error_body(type))

      expect { client.verify! }.to raise_error(described_class::Error) { |e|
        expect(e.code).to eq(code)
        expect(e.message).not_to include('sk-ant-test-key')
      }
    end
  end

  it 'maps connection failures to unavailable' do
    stub_request(:get, %r{api.anthropic.com}).to_raise(SocketError)

    expect { client.verify! }.to raise_error(described_class::Error) { |e| expect(e.code).to eq('unavailable') }
  end

  it 'marks rate limits and outages as retryable but not invalid keys' do
    expect(described_class::RetryableError.new('rate_limited')).to be_retryable
    expect(described_class::Error.new('invalid_key')).not_to be_retryable
  end

  it 'writes its messages in the language set in Settings' do
    stub_claude_models(status: 401, body: claude_error_body('authentication_error'))

    I18n.with_locale(:'pt-BR') do
      expect { client.verify! }.to raise_error(described_class::Error, /Sua chave de API do Claude foi recusada/)
    end
  end
end
