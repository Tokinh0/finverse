# Keeps `parsed_name` (upcased, underscored; see StringUtils#default_string_parse) in sync
# with `name`. Matching, seeding and lookups compare `parsed_name`, so it must follow
# every assignment of `name`, including updates.
module Normalizer
  extend ActiveSupport::Concern
  include StringUtils

  def name=(value)
    super
    self.parsed_name = value.nil? ? nil : default_string_parse(value)
  end
end
