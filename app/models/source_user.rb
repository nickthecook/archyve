# One person's standing with one source. See docs/architecture.md.
#
#   user     — may feed this source into a collection they administer
#   curator  —+ change its config and trigger a sync
#   admin    — + manage who else may, and delete it
#
# The `user` role exists because configuring a source and drawing on it are
# different mandates, and in an organisation they belong to different people.
# IT owns the credentials; the team that owns a collection decides what feeds
# it. Without this role, letting a collection curator attach a source would
# mean handing them the credentials too — or routing every attachment through
# an admin.
#
# What someone can actually do is capped by their global role, so a grant never
# raises anyone above their ceiling — see User#role_on.
class SourceUser < ApplicationRecord
  include Roleable

  belongs_to :source
  belongs_to :user

  validates :user_id, uniqueness: { scope: :source_id }
end
