# The global role vocabulary. Grants have their own — see Grantable.
module Roleable
  extend ActiveSupport::Concern

  ROLES = { visitor: 0, curator: 1, admin: 2 }.freeze

  included do
    enum :role, ROLES, validate: true
  end

  # Ordered roles, so "does this reach curator?" is `>=` rather than a list of
  # equality checks that has to be revisited whenever a role is added.
  def at_least?(minimum)
    return false if role.nil?

    ROLES.fetch(role.to_sym) >= ROLES.fetch(minimum.to_sym)
  end
end
