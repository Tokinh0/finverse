# Every example runs as a signed-in profile, the way the app always does: data built in a spec
# belongs to `current_profile`, and request specs send its session token.
#
# - `current_profile` is the example's profile (Current.profile while it runs).
# - `as_profile(other) { ... }` builds or reads data as another profile.
# - Request helpers (get/post/...) add the bearer token unless `headers:` already has an
#   Authorization (pass `headers: { "Authorization" => "" }` to call anonymously).
module CurrentProfileHelpers
  def current_profile
    @current_profile ||= create(:profile)
  end

  def as_profile(profile, &)
    Current.set(profile: profile, &)
  end

  def auth_headers(profile = current_profile)
    @auth_tokens ||= {}
    @auth_tokens[profile.id] ||= ProfileSession.start!(profile).token
    { "Authorization" => "Bearer #{@auth_tokens[profile.id]}" }
  end
end

module AuthenticatedRequests
  %i[get post patch put delete].each do |verb|
    define_method(verb) do |path, **kwargs|
      headers = kwargs[:headers] || {}
      kwargs[:headers] = headers.key?("Authorization") ? headers : auth_headers.merge(headers)
      super(path, **kwargs).tap do
        # The request resets Current when it ends; the spec keeps working as its profile.
        Current.profile = current_profile
      end
    end
  end
end

RSpec.configure do |config|
  config.include CurrentProfileHelpers
  config.include AuthenticatedRequests, type: :request

  config.before { Current.profile = current_profile }
  config.after { Current.reset }
end
