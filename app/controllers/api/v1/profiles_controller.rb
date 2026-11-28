module Api::V1
  # The profile picker: GET lists the account's profiles and POST adds one (with the default
  # categories). Both work before signing in, since picking a profile is how one signs in.
  class ProfilesController < ApplicationController
    skip_before_action :authenticate_profile!

    def index
      render json: Account.default.profiles.order(:created_at, :id).map { ProfilePresenter.new(_1) }
    end

    # Body: { profile: { name, password?, locale? } }
    def create
      attrs = params.require(:profile).permit(:name, :password, :locale)
      profile = Profiles::Setup.call(
        account: Account.default, name: attrs[:name], password: attrs[:password].presence,
        locale: attrs[:locale].presence || I18n.locale.to_s
      )

      if profile.persisted?
        render json: ProfilePresenter.new(profile), status: :created
      else
        render json: { errors: profile.errors.full_messages }, status: :unprocessable_content
      end
    end
  end
end
