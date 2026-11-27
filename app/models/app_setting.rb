# The single row of app-wide settings. Use `AppSetting.current`.
#
# The Claude API key is encrypted at rest (Active Record Encryption, keys in the Rails
# credentials) and never leaves the API: presenters only expose a masked form.
class AppSetting < ApplicationRecord
  DEFAULT_CLAUDE_MODEL = "claude-haiku-5-5".freeze

  encrypts :claude_api_key

  validates :claude_model, format: { with: /\Aclaude-[a-z0-9.-]+\z/ }, allow_blank: true

  def self.current
    first_or_create!
  end

  def claude_configured?
    claude_api_key.present?
  end

  # Model set in settings, else CLAUDE_MODEL from the environment, else the default.
  def effective_claude_model
    claude_model.presence || ENV["CLAUDE_MODEL"].presence || DEFAULT_CLAUDE_MODEL
  end

  # "sk-ant-…a1B2": enough to recognize the key, useless to anyone who sees it.
  def masked_claude_api_key
    return nil unless claude_configured?

    "#{claude_api_key.first(7)}…#{claude_api_key.last(4)}"
  end

  # Keeps `inspect` and error reports from printing the decrypted key.
  def inspect
    super.sub(/claude_api_key: "[^"]*"/, 'claude_api_key: "[FILTERED]"')
  end
end
