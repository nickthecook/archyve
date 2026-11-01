# One person's access to one collection. See docs/architecture.md.
#
#   user     — search it, and draw on it in chat
#   curator  —+ add and remove documents by hand, trigger a sync
#   admin    — + change the collection, manage who else may use it, delete it
#
# What someone can actually do is the lower of this and their global role, so a
# grant never raises anyone above their ceiling — see User#role_on.
class CollectionUser < ApplicationRecord
  include Roleable

  belongs_to :collection
  belongs_to :user

  validates :user_id, uniqueness: { scope: :collection_id }
end
