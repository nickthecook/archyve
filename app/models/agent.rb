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

  # Slugs are route segments under /settings/agents.
  RESERVED_SLUGS = %w[new].freeze

  before_validation :set_slug, on: :create

  validates :slug, presence: true, uniqueness: true, exclusion: { in: RESERVED_SLUGS }
  validates :name, presence: true
  validates :creator, presence: true, if: -> { creator_only? && new_record? }
  validate :toolsets_exist

  def self.archivist = find_by!(slug: "archivist")
  def self.admin_support = find_by!(slug: "admin_support")

  # Falls back to Archivist when the setting names an agent that has since
  # stopped qualifying, so a new chat always has someone to answer it.
  def self.default_chat
    chosen = find_by(slug: Setting.chat_default_agent)
    chosen&.default_eligible? ? chosen : archivist
  end

  # What Chat's picker offers. Admin Support is started from Settings › Admin instead.
  def self.choosable_by(user) = where.not(slug: "admin_support").order(:name).select { it.usable_by?(user) }

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

  # The default answers everyone's new chats, so it has to be usable by everyone.
  def default_eligible? = everyone? && role_floor == :visitor

  # Private to whoever copied it until they choose to share it.
  def duplicate(by:)
    Agent.new(
      name: "#{name} (copy)", prompt:, toolset_keys:, collection_mode:, collection_ids:,
      access_mode: "creator_only", creator: by
    )
  end

  def removal_refusal
    return "Built-in agents can't be removed." if built_in?
    return unless conversations.exists?

    count = conversations.count
    "It's in #{count} #{'conversation'.pluralize(count)}, which would lose who answered them."
  end

  private

  def set_slug
    return if slug.present? || name.blank?

    base = name.parameterize.presence || "agent"
    base = "#{base}-agent" if RESERVED_SLUGS.include?(base)
    self.slug = (1..).lazy.map { it == 1 ? base : "#{base}-#{it}" }.find { !Agent.exists?(slug: it) }
  end

  def toolsets_exist
    unknown = toolset_keys - Toolsets.keys
    errors.add(:toolset_keys, "names unknown toolsets: #{unknown.join(', ')}") if unknown.any?
  end
end
