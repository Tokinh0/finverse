# lib/json_utils.rb

module JsonUtils
  def load_initial_data
    content = File.read(Rails.root.join('db', 'seed_data', ENV['DEFAULT_DATA_FILE_PATHNAME']))
    json = content.lines.reject { |line| line.strip.start_with?('//') }.join
    JSON.parse(json)
  rescue JSON::ParserError => e
    puts "❌ Failed to parse JSON: #{e.message}"
    exit(1)
  end

  module_function :load_initial_data
end
