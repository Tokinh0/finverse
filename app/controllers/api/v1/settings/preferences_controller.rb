module Api::V1::Settings
  # GET/PUT /settings/preferences: the signed-in profile's preferences. Today only the language
  # ("en" or "pt-BR"), used by the UI, the API's messages and the reasons Claude writes.
  class PreferencesController < ApplicationController
    def show
      render json: present
    end

    # Body: { preferences: { locale } }
    def update
      profile = Current.profile
      if profile.update(params.require(:preferences).permit(:locale))
        I18n.with_locale(profile.locale) { render json: present }
      else
        render json: { errors: profile.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def present
      { locale: Current.profile.locale, available_locales: Profile::LOCALES }
    end
  end
end
