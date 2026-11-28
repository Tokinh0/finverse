# Who owns the app: today the single account of this install, later the email login. An account
# has a few profiles (one per person using it) and the settings they share, like the Claude key.
class Account < ApplicationRecord
  DEFAULT_NAME = "Finverse".freeze
  MAX_PROFILES = 6

  has_many :profiles, dependent: :restrict_with_error
  has_one :app_setting, dependent: :destroy

  validates :name, presence: true
  validates :email, uniqueness: { case_sensitive: false }, allow_nil: true

  # Until accounts can sign in, every profile belongs to the install's one account.
  def self.default
    order(:id).first || create!(name: DEFAULT_NAME)
  end
end
