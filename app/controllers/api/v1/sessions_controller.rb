module Api::V1
  # POST signs a profile in (with its password, if it has one) and returns the session token the
  # client sends as `Authorization: Bearer <token>`. GET returns the signed-in profile, DELETE
  # signs out. Switching profiles = signing out and picking another one.
  class SessionsController < ApplicationController
    skip_before_action :authenticate_profile!, only: :create

    def show
      render json: { profile: ProfilePresenter.new(Current.profile) }
    end

    # Body: { profile_id, password? }
    def create
      profile = Account.default.profiles.find_by(id: params[:profile_id])
      return render json: { errors: [ I18n.t("auth.profile_not_found") ] }, status: :not_found unless profile

      unless profile.unlocks_with?(params[:password])
        return render json: { errors: [ I18n.t("auth.wrong_password") ] }, status: :unauthorized
      end

      session = ProfileSession.start!(profile)
      I18n.with_locale(profile.locale) do
        render json: { token: session.token, profile: ProfilePresenter.new(profile) }, status: :created
      end
    end

    def destroy
      Current.session.destroy
      head :no_content
    end
  end
end
