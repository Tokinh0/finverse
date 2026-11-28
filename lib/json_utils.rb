# lib/json_utils.rb

module JsonUtils
  DEFAULT_FILE = "defaults.jsonc".freeze

  # Reads db/seed_data/$DEFAULT_DATA_FILE_PATHNAME (defaults.jsonc when unset): JSON with
  # `//` line comments.
  def load_initial_data
    name = ENV["DEFAULT_DATA_FILE_PATHNAME"].presence || DEFAULT_FILE
    content = File.read(Rails.root.join("db", "seed_data", name))
    JSON.parse(content.lines.reject { |line| line.strip.start_with?("//") }.join)
  end

  module_function :load_initial_data
end
