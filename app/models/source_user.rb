# One person's standing with one source. See docs/architecture.md.
#
#   accessor — may feed this source into a collection they can edit
#   editor   — + change its config and trigger a sync
#   manager  — + delete it
#
# `accessor` exists because configuring a source and drawing on it are
# different mandates, and in an organisation they belong to different people.
# IT owns the credentials; the team that owns a collection decides what feeds
# it. Without it, letting a collection's editor attach a source would mean
# handing them the credentials too — or routing every attachment through an
# admin.
#
# A grant never raises anyone above their global role — see User#grant_on.
class SourceUser < ApplicationRecord
  include Grantable

  belongs_to :source
  belongs_to :user

  validates :user_id, uniqueness: { scope: :source_id }
end
