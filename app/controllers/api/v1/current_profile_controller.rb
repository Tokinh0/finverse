module Api::V1
  # GET/PATCH /profile: the signed-in profile's name, language and password.
  class CurrentProfileController < ApplicationController
    def show
      render json: ProfilePresenter.new(Current.profile)
    end

    # Body: { profile: { name?, locale?, password?, remove_password?, current_password? } }
    # Changing or removing a password needs the current one.
    def update
      attrs = params.require(:profile).permit(:name, :locale, :password, :remove_password, :current_password)
      profile = Profiles::Update.call(Current.profile, attrs.to_h.symbolize_keys, keep_session: Current.session)

      if profile.errors.empty?
        I18n.with_locale(profile.locale) { render json: ProfilePresenter.new(profile) }
      else
        render json: { errors: profile.errors.full_messages }, status: :unprocessable_content
      end
    end
  end
end
