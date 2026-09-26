class Collection < ApplicationRecord
  has_many :source_collections, dependent: :destroy
  has_many :sources, through: :source_collections

  has_many :collection_users, dependent: :destroy
  has_many :users, through: :collection_users

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

  # Everything this person can reach at all — any grant, however weak, since
  # even the weakest is enough to search it and draw on it in chat.
  scope :readable_by, ->(user) {
    next all if user.admin?

    where(id: CollectionUser.where(user:).select(:collection_id))
  }

  # Everything they can change. Needs the ceiling *and* the grant to reach
  # operator: a global `user` granted collection admin is still only a reader.
  scope :manageable_by, ->(user) {
    next none unless user.at_least?(:operator)
    next all if user.admin?

    where(id: CollectionUser.where(user:).where(role: [:operator, :admin]).select(:collection_id))
  }

  # Everything they can hand out access to, or delete. Collection admin is
  # reachable by a global operator — owning a collection includes deciding who
  # uses it — but never by a global user, whose ceiling is reading.
  scope :administrable_by, ->(user) {
    next none unless user.at_least?(:operator)
    next all if user.admin?

    where(id: CollectionUser.where(user:, role: :admin).select(:collection_id))
  }

  # The grant itself, or nil. User#role_on combines it with the global role;
  # Source answers the same question, so the two are interchangeable there.
  def granted_role_for(user)
    collection_users.find_by(user:)&.role
  end

  # A collection has no grants until it has one, so whoever creates it has to be
  # given it — otherwise an operator immediately can't manage the thing they
  # just made, and only an admin could rescue them.
  def grant_admin_to!(user)
    collection_users.create!(user:, role: :admin)
  end

  # Collections are addressed by slug (routes use `param: :slug`), so URL
  # helpers must build /collections/:slug, not /collections/:id.
  def to_param = slug

  private

  def set_slug
    self.slug ||= name&.parameterize
  end
end
