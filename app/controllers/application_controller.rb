class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  # Messages use the signed-in profile's language; before sign-in, the browser's.
  around_action :use_request_locale
  # Every endpoint works for the profile whose session token comes as `Authorization: Bearer …`.
  # The profile picker endpoints skip this.
  before_action :authenticate_profile!

  # Includes records of other profiles: for this profile they don't exist.
  rescue_from ActiveRecord::RecordNotFound do
    render json: { errors: [ I18n.t("records.not_found") ] }, status: :not_found
  end

  private

  def use_request_locale(&)
    I18n.with_locale(request_locale, &)
  end

  def authenticate_profile!
    session = authenticate_with_http_token { |token, _options| ProfileSession.find_active(token) }
    return render_unauthenticated unless session

    Current.session = session
    Current.profile = session.profile
    I18n.locale = Current.profile.locale
  end

  def render_unauthenticated
    render json: { error: "unauthenticated", errors: [ I18n.t("auth.unauthenticated") ] }, status: :unauthorized
  end

  # The first language from Accept-Language the app speaks ("pt", "pt-PT" → "pt-BR").
  def request_locale
    request.headers["Accept-Language"].to_s.split(",").each do |part|
      tag = part.split(";").first.to_s.strip
      return tag if Profile::LOCALES.include?(tag)
      return "pt-BR" if tag.downcase.start_with?("pt")
      return "en" if tag.downcase.start_with?("en")
    end
    I18n.default_locale.to_s
  end
end
