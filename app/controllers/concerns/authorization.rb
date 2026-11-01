# Role gating, as a companion to Authentication. That concern answers "is
# anyone there?"; this one answers "are they allowed to do this?".
#
# Deliberately only the *global* role — the capability ceiling. Per-collection
# and per-source grants land separately and combine with `min`, so a grant can
# never raise someone above the ceiling this sets.
module Authorization
  extend ActiveSupport::Concern

  class_methods do
    # Gate a controller, or some of its actions, on a minimum role:
    #
    #   require_role :curator
    #   require_role :admin, only: :destroy
    #
    # Takes a minimum rather than a list because roles are ordered, so an admin
    # never has to be named alongside a curator to be let through.
    def require_role(minimum, **options)
      before_action(**options) { require_at_least(minimum) }
    end
  end

  private

  def require_at_least(minimum)
    return if Current.user&.at_least?(minimum)

    # Root is the corridor, which everyone can reach, so this can't loop.
    redirect_to root_path, alert: "You don't have access to that."
  end
end
