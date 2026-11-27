module Api::V1::Settings
  # GET/PUT /settings/preferences: app-wide preferences. Today only the language
  # ("en" or "pt-BR"), used by the UI, the API's messages and the reasons Claude writes.
  class PreferencesController < ApplicationController
    def show
      render json: present
    end

    # Body: { preferences: { locale } }
    def update
      setting = AppSetting.current
      if setting.update(params.require(:preferences).permit(:locale))
        I18n.with_locale(setting.locale) { render json: present }
      else
        render json: { errors: setting.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def present
      { locale: AppSetting.current.locale, available_locales: AppSetting::LOCALES }
    end
  end
end
