require 'string_utils'

ActiveSupport.on_load(:active_record) { include StringUtils }
ActiveSupport.on_load(:action_controller) { include StringUtils }
ActiveSupport.on_load(:action_view) { include StringUtils }
ActiveSupport.on_load(:active_job) { include StringUtils }

# Make it available in plain Ruby objects like service classes or parsers
Object.include(StringUtils) if defined?(Rails::Console) || defined?(Rails::Server)
