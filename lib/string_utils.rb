# lib/string_utils.rb

module StringUtils
  def default_string_parse(string)
    string.to_s.strip.upcase.gsub(/\s+/, "_")
  end

  module_function :default_string_parse
end
