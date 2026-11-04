class Agent < ApplicationRecord
  BUILT_INS = {
    "archivist" => {
      name: "Archivist",
      prompt: "You are a chat assistant for a private document archive.",
      toolset_keys: ["archive"]
    },
    "admin_support" => {
      name: "Admin Support",
      prompt: "You are Admin Support, helping an administrator of this Archyve instance work out " \
              "what is wrong with it and what to do about it. Be direct and specific.",
      toolset_keys: ["admin_support"]
    }
  }.freeze

  has_many :conversations, dependent: :restrict_with_exception

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
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

  def usable_by?(user) = user.at_least?(role_floor)

  def admin_support? = slug == "admin_support"

  def searches_archive? = toolset_keys.include?(Toolsets::Archive.key)

  private

  def toolsets_exist
    unknown = toolset_keys - Toolsets.keys
    errors.add(:toolset_keys, "names unknown toolsets: #{unknown.join(', ')}") if unknown.any?
  end
end
