module Profiles
  # Creates a profile ready to use: the profile plus the default categories, subcategories and
  # keyword rules (Profiles::DefaultData), all or nothing.
  module Setup
    module_function

    # @return [Profile] persisted, or with errors when it couldn't be created
    def call(account:, name:, password: nil, locale: "en")
      profile = account.profiles.new(name: name, password: password, locale: locale)
      Profile.transaction do
        raise ActiveRecord::Rollback unless profile.save

        Current.set(profile: profile) { DefaultData.apply }
      end
      profile
    end
  end
end
