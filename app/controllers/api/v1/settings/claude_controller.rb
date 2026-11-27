module Api::V1::Settings
  # GET/PUT/DELETE /settings/claude: the owner's Claude API key and model.
  #
  # A new key is checked with one cheap API call before it is saved. A key Claude rejects is
  # not saved; when Claude can't be reached, the key is saved and the response carries a warning.
  class ClaudeController < ApplicationController
    def show
      render json: ClaudeSettingPresenter.new(setting)
    end

    # Body: { claude: { api_key, model } }; both optional.
    def update
      api_key = claude_params[:api_key].to_s.strip.presence
      warning = verify(api_key) if api_key
      return if performed?

      setting.claude_api_key = api_key if api_key
      setting.claude_model = claude_params[:model].to_s.strip.presence if claude_params.key?(:model)

      if setting.save
        render json: ClaudeSettingPresenter.new(setting, warning: warning)
      else
        render json: { errors: setting.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      setting.update!(claude_api_key: nil)
      render json: ClaudeSettingPresenter.new(setting)
    end

    private

    def setting
      @setting ||= AppSetting.current
    end

    def claude_params
      params.fetch(:claude, {}).permit(:api_key, :model)
    end

    # @return [String, nil] a warning when the key couldn't be checked
    def verify(api_key)
      Ai::Client.new(api_key: api_key, model: setting.effective_claude_model).verify!
      nil
    rescue Ai::Client::Error => e
      return e.message unless e.code == "invalid_key"

      render json: { errors: [ e.message ] }, status: :unprocessable_content
      nil
    end
  end
end
