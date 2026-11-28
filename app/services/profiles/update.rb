module Profiles
  # Changes a profile's name, language or password. Setting, changing or removing a password
  # needs the current one (when there is one), and signs the profile out everywhere else.
  module Update
    module_function

    # @param attrs [Hash] :name, :locale, :password, :remove_password, :current_password
    # @param keep_session [ProfileSession, nil] the session making the change, kept signed in
    # @return [Profile] with errors when nothing was saved
    def call(profile, attrs, keep_session: nil)
      new_password = attrs[:password].presence
      remove_password = ActiveModel::Type::Boolean.new.cast(attrs[:remove_password])
      changes_password = new_password || (remove_password && profile.password_protected?)

      if changes_password && !profile.unlocks_with?(attrs[:current_password])
        profile.errors.add(:current_password, :wrong)
        return profile
      end

      profile.name = attrs[:name] if attrs.key?(:name)
      profile.locale = attrs[:locale] if attrs.key?(:locale)
      if new_password
        profile.password = new_password
      elsif remove_password
        profile.password = nil
      end

      Profile.transaction do
        raise ActiveRecord::Rollback unless profile.save

        profile.sessions.where.not(id: keep_session&.id).delete_all if changes_password
      end
      profile
    end
  end
end
