# A signed-in profile on one browser. The client keeps the token and sends it as a bearer token;
# only its SHA-256 digest is stored. Sessions end on sign-out or after IDLE_TIMEOUT unused.
class ProfileSession < ApplicationRecord
  IDLE_TIMEOUT = 30.days
  TOUCH_EVERY = 1.hour

  belongs_to :profile

  # The plain token, only available right after start!.
  attr_reader :token

  class << self
    def start!(profile)
      token = SecureRandom.urlsafe_base64(32)
      create!(profile: profile, token_digest: digest(token), last_used_at: Time.current).tap do |session|
        session.instance_variable_set(:@token, token)
      end
    end

    # @return [ProfileSession, nil] the live session for this token, touched as it's used
    def find_active(token)
      return if token.blank?

      session = includes(:profile).find_by(token_digest: digest(token))
      return unless session

      if session.last_used_at < IDLE_TIMEOUT.ago
        session.destroy
        return
      end

      session.update_column(:last_used_at, Time.current) if session.last_used_at < TOUCH_EVERY.ago
      session
    end

    def digest(token)
      OpenSSL::Digest::SHA256.hexdigest(token)
    end
  end
end
