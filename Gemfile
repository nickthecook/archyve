source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.7"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"

# Views as composable Ruby objects instead of ERB [https://www.phlex.fun]
gem "phlex-rails"

# pgvector support for Active Record: vector columns + nearest-neighbor search
gem "neighbor"

# Cursor pagination for Active Record. Chosen over an offset pager because the
# admin lists are written to while they are read; chosen over Pagy and Kaminari
# because it renders nothing — the nav is a Phlex component. See docs/design.md.
gem "activerecord_cursor_paginate"

# Markdown for what the model writes back. GFM, because that is the dialect
# models emit — tables, fenced code, strikethrough — and it escapes raw HTML
# rather than trusting a completion with the page.
gem "commonmarker"

# Multi-provider LLM client: tool calling + streaming (Ollama first)
gem "ruby_llm", "~> 2.2"

# HTTP client for outbound service calls (Docling, sources). One Faraday
# stack shared with RubyLLM; middleware gives us logging, retries, and
# ActiveSupport::Notifications instrumentation for live pipeline stats.
gem "faraday"
gem "faraday-multipart"  # multipart file uploads to docling-serve
gem "faraday-retry"      # backoff for slow/flaky local services
gem "json", "~> 2.21"    # json 3 takes parse options as keywords only; Faraday 2.14's JSON middleware passes a hash
gem "json_schemer", "~> 2.5" # validates API tool arguments
gem "nokogiri"           # HTML5 parsing for the web source (transitive via loofah, but used directly)
gem "csv"                # the Review export; a bundled gem rather than a default one since Ruby 3.4

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Web dashboard for Solid Queue jobs, mounted at /jobs (admin-only)
gem "mission_control-jobs"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.2"
gem "ruby-vips", "~> 2.3"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # RSpec as the test framework (Minitest skipped at generate time)
  gem "rspec-rails"

  # Test data builders
  gem "factory_bot_rails"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

gem "pry-rails", "~> 0.3.11"

gem "fuubar", "~> 2.5"

gem "active_storage_validations", "~> 4.1"
