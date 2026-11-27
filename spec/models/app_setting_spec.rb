require 'rails_helper'

RSpec.describe AppSetting do
  it 'keeps a single row' do
    expect(described_class.current).to eq(described_class.current)
    expect(described_class.count).to eq(1)
  end

  it 'stores the API key encrypted' do
    setting = described_class.current
    setting.update!(claude_api_key: 'sk-ant-api03-secretvalue1234')

    raw = described_class.connection.select_value("SELECT claude_api_key FROM app_settings WHERE id = #{setting.id}")
    expect(raw).not_to include('secretvalue')
    expect(setting.reload.claude_api_key).to eq('sk-ant-api03-secretvalue1234')
  end

  it 'masks the key and hides it from inspect' do
    setting = described_class.new(claude_api_key: 'sk-ant-api03-secretvalue1234')

    expect(setting.masked_claude_api_key).to eq('sk-ant-…1234')
    expect(setting.inspect).not_to include('secretvalue')
    expect(described_class.new.masked_claude_api_key).to be_nil
  end

  describe '#effective_claude_model' do
    it 'prefers the saved model, then CLAUDE_MODEL, then the default' do
      expect(described_class.new(claude_model: 'claude-sonnet-5-5').effective_claude_model).to eq('claude-sonnet-5-5')
      stub_const('ENV', ENV.to_h.merge('CLAUDE_MODEL' => 'claude-opus-5-5'))
      expect(described_class.new.effective_claude_model).to eq('claude-opus-5-5')
      stub_const('ENV', ENV.to_h.except('CLAUDE_MODEL'))
      expect(described_class.new.effective_claude_model).to eq(AppSetting::DEFAULT_CLAUDE_MODEL)
    end
  end

  it 'rejects model names that are not Claude models' do
    expect(described_class.new(claude_model: 'gpt-5')).not_to be_valid
  end
end
