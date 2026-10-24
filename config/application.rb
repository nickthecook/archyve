require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../lib/archyve/keys"

module Archyve
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[archyve assets generators tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Mission Control - Jobs dashboard reads Solid Queue's tables directly.
    config.mission_control.jobs.adapters = [:solid_queue]

    # Active Record encryption keys come from the environment, not credentials,
    # so every environment can hold its own without anyone managing a master.key
    # — ops loads them from config/<env>/secrets.ejson, and production falls
    # back to a generated key file (config/environments/production.rb). The
    # railtie splats `config.active_record.encryption` *after* its credentials
    # lookup, so these win. Guarded, because assigning nil would override the
    # credentials fallback rather than defer to it.
    #
    # Losing these makes every encrypted column permanently unreadable — they
    # are not derived from SECRET_KEY_BASE, or from anything else.
    Archyve::Keys::ENCRYPTION.each do |setting, variable|
      value = ENV[variable].presence
      config.active_record.encryption.public_send(:"#{setting}=", value) if value
    end
  end
end
