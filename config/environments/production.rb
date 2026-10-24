require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Skipped for assets:precompile in the image build, which must never write keys.
  unless ENV["SECRET_KEY_BASE_DUMMY"]
    keys = Archyve::Keys.new(ENV.fetch("ARCHYVE_KEYS_FILE", Rails.root.join("keys/archyve.yml")))
    config.secret_key_base = keys["SECRET_KEY_BASE"]
    Archyve::Keys::ENCRYPTION.each do |setting, variable|
      config.active_record.encryption.public_send(:"#{setting}=", keys[variable])
    end
  end

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Production is behind a TLS-terminating reverse proxy. assume_ssl is
  # what makes request.base_url say https, and therefore what makes
  # sso_callback_url generate a redirect_uri the IdP will accept; force_ssl is
  # what marks the session cookie secure. ARCHYVE_FORCE_TLS=false turns both
  # off, for running the image locally over plain HTTP.
  force_tls = ENV["ARCHYVE_FORCE_TLS"] != "false"
  config.assume_ssl = force_tls
  config.force_ssl = force_tls
  unless force_tls
    config.after_initialize { Rails.logger.warn("ARCHYVE_FORCE_TLS=false: serving plain HTTP, with insecure cookies") }
  end

  health_checks = %r{\A/up(/queues)?\z}

  # Skip http-to-https redirect for the health check endpoints.
  config.ssl_options = { redirect: { exclude: ->(request) { health_checks.match?(request.path) } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = health_checks

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: ENV.fetch("ARCHYVE_HOST", "localhost") }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks. This is
  # load-bearing for SSO: the OIDC redirect_uri is derived from the Host header,
  # so without it a spoofed Host can aim the callback elsewhere. The IdP's own
  # allowlist is the real backstop; this closes it at our end too.
  #
  # Guarded rather than defaulted: an allow list containing the wrong host
  # rejects every real request, which is a worse failure than not having one.
  #
  # ARCHYVE_EXTRA_HOSTS (comma-separated) adds further permitted hosts
  # alongside ARCHYVE_HOST, e.g. an internal hostname used for health checks.
  if (host = ENV["ARCHYVE_HOST"].presence)
    config.hosts = [host, *ENV.fetch("ARCHYVE_EXTRA_HOSTS", "").split(",").map(&:strip)]
  end

  # Skip DNS rebinding protection for the health check endpoints.
  config.host_authorization = { exclude: ->(request) { health_checks.match?(request.path) } }
end
