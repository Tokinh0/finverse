# One person using the account. All financial data belongs to a profile (see ProfileOwned), and
# each profile picks its own language. A password is optional: without one, picking the profile
# is enough to enter it.
class Profile < ApplicationRecord
  LOCALES = %w[en pt-BR].freeze

  has_secure_password validations: false

  # Only for error messages about the password a change was confirmed with (Profiles::Update).
  attr_accessor :current_password

  belongs_to :account
  has_many :sessions, class_name: "ProfileSession", dependent: :delete_all

  validates :name, presence: true, length: { maximum: 40 }, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :locale, inclusion: { in: LOCALES }
  validates :password, length: { minimum: 4, maximum: 72 }, allow_nil: true
  validates :color_code, format: { with: /\A#\h{6}\z/ }, allow_blank: true
  validate :account_has_room, on: :create

  before_validation { self.name = name.to_s.squish }

  def password_protected?
    password_digest.present?
  end

  # True when the profile may be entered with this password (any, when it has none).
  def unlocks_with?(password)
    !password_protected? || authenticate(password.to_s).present?
  end

  private

  def account_has_room
    return unless account && account.profiles.count >= Account::MAX_PROFILES

    errors.add(:base, :too_many_profiles, count: Account::MAX_PROFILES)
  end
end
