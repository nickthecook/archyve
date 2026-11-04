class Agent < ApplicationRecord
  BUILT_INS = {
    "archivist" => {
      name: "Archivist",
      prompt: "You are a chat assistant for a private document archive.",
      toolset_keys: ["archive"],
      access_mode: "everyone",
      collection_mode: "user"
    },
    "admin_support" => {
      name: "Admin Support",
      prompt: "You are Admin Support, helping an administrator of this Archyve instance work out " \
              "what is wrong with it and what to do about it. Be direct and specific.",
      toolset_keys: ["admin_support"],
      access_mode: "everyone",
      collection_mode: "fixed"
    }
  }.freeze

  # Who may chat with it. See "Agents" in docs/architecture.md.
  enum :access_mode, { everyone: 0, granted: 1, creator_only: 2 }, validate: true

  # `user`: whatever the person chatting can read, narrowed by the picker.
  # `fixed`: exactly the agent's own collections, shared with everyone who can use it.
  enum :collection_mode, { user: 0, fixed: 1 }, suffix: :collections, validate: true

  belongs_to :creator, class_name: "User", optional: true

  has_many :conversations, dependent: :restrict_with_exception
  has_many :agent_users, dependent: :destroy
  has_many :agent_collections, dependent: :destroy
  has_many :collections, through: :agent_collections

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
  validates :creator, presence: true, if: -> { creator_only? && new_record? }
  validate :toolsets_exist

  def self.archivist = find_by!(slug: "archivist")
  def self.admin_support = find_by!(slug: "admin_support")

  # Built-ins are locked, so this code is their source of truth: every seed rewrites them.
  def self.seed_built_ins!
    BUILT_INS.each do |slug, attributes|
      find_or_initialize_by(slug:).update!(**attributes, built_in: true)
    end
  end

  def to_param = slug

  def toolsets = toolset_keys.map { Toolsets.fetch(it) }

  def role_floor = toolsets.map(&:role_floor).max_by { Roleable::ROLES.fetch(it) } || :visitor

  # Checked on every turn, so a revoked grant or a raised floor takes effect mid-conversation.
  # Creator-only has no admin exception: a private agent is private.
  def usable_by?(user)
    return false unless user.at_least?(role_floor)
    return user.may_on?(self, :accessor) if granted?
    return creator_id.present? && creator_id == user.id if creator_only?

    true
  end

  def granted_access_for(user) = agent_users.find_by(user:)&.access

  def admin_support? = slug == "admin_support"

  def searches_archive? = toolset_keys.include?(Toolsets::Archive.key)

  # Whether the person chatting picks what it draws on. A fixed set can't be narrowed.
  def narrowable? = searches_archive? && user_collections?

  private

  def toolsets_exist
    unknown = toolset_keys - Toolsets.keys
    errors.add(:toolset_keys, "names unknown toolsets: #{unknown.join(', ')}") if unknown.any?
  end
end
