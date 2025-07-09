module Normalizer
  extend ActiveSupport::Concern

  included do
    if self < ActiveRecord::Base
      after_initialize :set_parsed_name, if: -> { respond_to?(:name) && respond_to?(:parsed_name=) }
    end
  end

  def set_parsed_name
    self.parsed_name = default_string_parse(name) if respond_to?(:name) && name
  end
end
