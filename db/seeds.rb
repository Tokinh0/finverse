# Everything a fresh install needs, safe to run again (bin/rails db:seed):
#
# - the account (until accounts can sign in, the install has one);
# - a "Default" profile when the account has none yet;
# - the profiles named in $SEED_PROFILES (comma-separated, set in .env so names stay out of the
#   public repo), created with the default categories;
# - the "Outros" fallback in every profile, since imports need it.
#
# New profiles start with the categories, subcategories and keyword rules from
# db/seed_data/defaults.jsonc (Profiles::DefaultData). Existing profiles are never reseeded, so
# their own categories stay as the owner left them. Profiles are created without a password;
# set one in the app (Settings → Profile).
seed_profiles = ENV.fetch("SEED_PROFILES", "").split(",").map(&:strip).reject(&:empty?)
default_profile = "Default"

account = Account.default
names = account.profiles.exists? ? seed_profiles : [ default_profile, *seed_profiles ]

names.each do |name|
  next if account.profiles.where("lower(name) = ?", name.downcase).exists?

  profile = Profiles::Setup.call(account: account, name: name, locale: "pt-BR")
  raise "Could not create profile #{name}: #{profile.errors.full_messages.to_sentence}" unless profile.persisted?

  puts "Created profile #{name} with #{Current.set(profile: profile) { Subcategory.count }} subcategories"
end

account.profiles.find_each { |profile| Current.set(profile: profile) { Profiles::DefaultData.ensure_fallback } }
