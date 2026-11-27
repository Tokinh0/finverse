# The Claude settings as the client may see them. The key itself is never included.
class ClaudeSettingPresenter
  def initialize(setting, warning: nil)
    @setting = setting
    @warning = warning
  end

  def as_json(*)
    {
      configured: @setting.claude_configured?,
      masked_key: @setting.masked_claude_api_key,
      model: @setting.effective_claude_model,
      default_model: AppSetting::DEFAULT_CLAUDE_MODEL,
      warning: @warning
    }
  end
end
