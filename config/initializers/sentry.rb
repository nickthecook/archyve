# frozen_string_literal: true

sentry_dsn = ENV.fetch("SENTRY_DSN", nil)

if sentry_dsn
  Sentry.init do |config|
    config.dsn = sentry_dsn

    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  end
end
