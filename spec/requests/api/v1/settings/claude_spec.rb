require 'rails_helper'

RSpec.describe 'Api::V1::Settings::Claude' do
  let(:key) { 'sk-ant-api03-secretvalue1234' }

  it 'reports that no key is configured' do
    get '/api/v1/settings/claude'

    expect(json).to include('configured' => false, 'masked_key' => nil, 'model' => AppSetting::DEFAULT_CLAUDE_MODEL)
  end

  it 'checks and saves a key, returning only its masked form' do
    stub_claude_models

    put '/api/v1/settings/claude', params: { claude: { api_key: " #{key} ", model: 'claude-sonnet-5-5' } }

    expect(response).to have_http_status(:ok)
    expect(json).to include('configured' => true, 'masked_key' => 'sk-ant-…1234', 'model' => 'claude-sonnet-5-5', 'warning' => nil)
    expect(response.body).not_to include('secretvalue')
    expect(AppSetting.current.claude_api_key).to eq(key)
  end

  it 'does not save a key Claude rejects' do
    stub_claude_models(status: 401, body: claude_error_body('authentication_error'))

    put '/api/v1/settings/claude', params: { claude: { api_key: key } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json['errors'].first).to match(/rejected/)
    expect(AppSetting.current).not_to be_claude_configured
  end

  it 'saves the key with a warning when Claude cannot be reached' do
    stub_request(:get, %r{api.anthropic.com}).to_raise(SocketError)

    put '/api/v1/settings/claude', params: { claude: { api_key: key } }

    expect(response).to have_http_status(:ok)
    expect(json['warning']).to match(/Couldn't reach/)
    expect(AppSetting.current).to be_claude_configured
  end

  it 'changes only the model without touching the key' do
    AppSetting.current.update!(claude_api_key: key)

    put '/api/v1/settings/claude', params: { claude: { model: 'claude-opus-5-5' } }

    expect(json).to include('configured' => true, 'model' => 'claude-opus-5-5')
  end

  it 'rejects an invalid model name' do
    put '/api/v1/settings/claude', params: { claude: { model: 'gpt-5' } }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'removes the key' do
    AppSetting.current.update!(claude_api_key: key)

    delete '/api/v1/settings/claude'

    expect(json).to include('configured' => false, 'masked_key' => nil)
    expect(AppSetting.current.reload.claude_api_key).to be_nil
  end
end
