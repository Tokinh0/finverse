# Data that belongs to one profile. The default scope limits every query to Current.profile and
# fills profile_id on new records, so services and controllers never pass the profile around.
# Without a current profile, queries raise MissingProfile instead of mixing people's data.
#
# Records may only point at records of the same profile (a subcategory id from another profile
# makes the record invalid). Use `unscoped` only where the profile is set explicitly, as jobs do.
module ProfileOwned
  extend ActiveSupport::Concern

  class MissingProfile < StandardError
    def initialize(message = "No profile selected. Set Current.profile first (e.g. Current.profile = Profile.first).")
      super
    end
  end

  included do
    belongs_to :profile

    default_scope { where(profile_id: ProfileOwned.current_profile_id) }

    validate :associations_in_same_profile
  end

  def self.current_profile_id
    Current.profile&.id || raise(MissingProfile)
  end

  private

  def associations_in_same_profile
    self.class.reflect_on_all_associations(:belongs_to).each do |reflection|
      next if reflection.polymorphic? || reflection.name == :profile || !reflection.klass.include?(ProfileOwned)
      next if self[reflection.foreign_key].nil?

      associated = public_send(reflection.name)
      if associated.nil?
        # Required associations already report "must exist".
        errors.add(reflection.name, :invalid) if reflection.options[:optional]
      elsif associated.profile_id != profile_id
        errors.add(reflection.name, :invalid)
      end
    end
  end
end
