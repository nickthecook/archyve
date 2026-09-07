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

  # Whether the signed-in user reaches a minimum role. Views use this to filter
  # affordances they shouldn't offer; controllers enforce the same thing with
  # `require_role`. Both are needed — hiding a link is not access control, and
  # showing one that bounces you is just a worse link.
  def may?(minimum)
    Current.user&.at_least?(minimum)
  end

  # The per-object counterpart: whether the signed-in user reaches a minimum
  # role *on this collection or source*, grant and ceiling combined.
  def may_on?(record, minimum)
    Current.user&.may_on?(record, minimum)
  end

  if Rails.env.development?
    def before_template
      comment { "Before #{self.class.name}" }
      super
    end
  end
end
