class Collection < ApplicationRecord
  has_many :source_collections, dependent: :destroy
  has_many :sources, through: :source_collections

  has_many :collection_users, dependent: :destroy
  has_many :users, through: :collection_users
  has_many :collection_groups, dependent: :destroy

  has_many :agent_collections, dependent: :destroy

  has_many :collection_memberships, dependent: :destroy
  has_many :active_memberships,
    -> { where(removed_at: nil) },
    class_name: "CollectionMembership"
  has_many :documents, through: :active_memberships

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # Blank is absent. A description that came back as "" would read as described
  # to `present?` and would be handed to the chat model as an empty field.
  normalizes :description, with: -> { it.strip.presence }

  before_validation :set_slug, on: :create

  # Granted directly or through any of the user's groups, at one of these levels.
  # Ignores the global role; the scopes below apply it.
  scope :granted_to, ->(user, access = Grantable::ACCESS.keys) {
    where(id: CollectionUser.where(user:, access:).select(:collection_id))
      .or(where(id: CollectionGroup.where(group_id: user.group_users.select(:group_id), access:).select(:collection_id)))
  }

  # Everything this person can reach at all — any grant, however weak, since
  # even the weakest is enough to search it and draw on it in chat.
  scope :readable_by, ->(user) {
    next all if user.admin?

    granted_to(user)
  }

  # Everything whose contents they can change. Needs the ceiling *and* the
  # grant: a visitor granted manager is still only an accessor.
  scope :manageable_by, ->(user) {
    next none unless user.at_least?(:curator)
    next all if user.admin?

    granted_to(user, [:editor, :manager])
  }

  # Everything they can describe or delete. Never reachable by a visitor, whose
  # ceiling is reading.
  scope :administrable_by, ->(user) {
    next none unless user.at_least?(:curator)
    next all if user.admin?

    granted_to(user, :manager)
  }

  # The strongest grant, direct or through a group, or nil. User#grant_on
  # combines it with the global role; Source answers the same question, so the
  # two are interchangeable there.
  def granted_access_for(user)
    Grantable.strongest(
      collection_users.where(user:).pluck(:access) +
        collection_groups.where(group_id: user.group_users.select(:group_id)).pluck(:access)
    )
  end

  # A collection has no grants until it has one, so whoever creates it has to be
  # given it — otherwise a curator immediately can't build the thing they just
  # made. Nobody else sees it until an admin grants them access.
  def grant_manager_to!(user)
    collection_users.create!(user:, access: :manager)
  end

  # Collections are addressed by slug (routes use `param: :slug`), so URL
  # helpers must build /collections/:slug, not /collections/:id.
  def to_param = slug

  private

  def set_slug
    self.slug ||= name&.parameterize
  end
end
