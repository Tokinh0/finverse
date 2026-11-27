require 'spec_helper'
require 'uri'
ENV['RAILS_ENV'] ||= 'test'
# DATABASE_URL may name the development database (e.g. in a local .env); always point specs at finverse_test.
ENV['DATABASE_URL'] = ENV.fetch('TEST_DATABASE_URL') do
  URI(ENV.fetch('DATABASE_URL', 'postgres://postgres:postgres@localhost:5432')).tap { |uri| uri.path = '/finverse_test' }.to_s
end
ENV['DEFAULT_DATA_FILE_PATHNAME'] = '../../spec/fixtures/seed_data/default_data.jsonc'
require_relative '../config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?
abort("Refusing to run specs against #{ActiveRecord::Base.connection_db_config.database}") unless ActiveRecord::Base.connection_db_config.database.end_with?('_test')
require 'rspec/rails'
require 'webmock/rspec'

Rails.root.glob('spec/support/**/*.rb').sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join('spec/fixtures') ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include FactoryBot::Syntax::Methods

  config.before { Keywords::TypeInference.reset! }
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
