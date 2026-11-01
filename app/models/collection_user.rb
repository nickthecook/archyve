# One person's access to one collection. See docs/architecture.md.
#
#   accessor — search it, and draw on it in chat
#   editor   — + add and remove documents by hand, trigger a sync
#   manager  — + change the collection, manage who else may use it, delete it
#
# A grant never raises anyone above their global role — see User#grant_on.
class CollectionUser < ApplicationRecord
  include Grantable

  belongs_to :collection
  belongs_to :user

  validates :user_id, uniqueness: { scope: :collection_id }
end
