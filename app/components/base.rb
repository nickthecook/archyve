# frozen_string_literal: true

class Components::Base < Phlex::HTML
  # Include any helpers you want to be available across all components. These are
  # phlex-rails helper adapters — they expose the Rails helper as a real method
  # so we call it directly (e.g. `form_authenticity_token`) instead of through the
  # deprecated `helpers` proxy.
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::FormAuthenticityToken
  include Phlex::Rails::Helpers::TimeAgoInWords
  include Phlex::Rails::Helpers::CurrentPage

  # No built-in adapter for cookies; register one so `cookies` works here too.
  register_value_helper :cookies

  if Rails.env.development?
    def before_template
      comment { "Before #{self.class.name}" }
      super
    end
  end
end
