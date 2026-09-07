# The role vocabulary, shared by every axis that has one: the global role on
# User, and the per-object grants beside it.
#
# One definition on purpose. The axes are combined by taking the *lower* of the
# two, and that is only meaningful if both sides are the same ordered integers.
# Two enums that happened to agree today would be a bug waiting for the day
# somebody added a value to one of them.
module Roleable
  extend ActiveSupport::Concern

  ROLES = { user: 0, operator: 1, admin: 2 }.freeze

  included do
    enum :role, ROLES, validate: true
  end

  # Ordered roles, so "does this reach operator?" is `>=` rather than a list of
  # equality checks that has to be revisited whenever a role is added.
  def at_least?(minimum)
    return false if role.nil?

    ROLES.fetch(role.to_sym) >= ROLES.fetch(minimum.to_sym)
  end
end
