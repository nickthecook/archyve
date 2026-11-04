class Agent < ApplicationRecord
  BUILT_INS = {
    "archivist" => {
      name: "Archivist",
      prompt: "You are a chat assistant for a private document archive."
    }
  }.freeze

  has_many :conversations, dependent: :restrict_with_exception

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true

  def self.archivist = find_by!(slug: "archivist")

  # Built-ins are locked, so this code is their source of truth: every seed rewrites them.
  def self.seed_built_ins!
    BUILT_INS.each do |slug, attributes|
      find_or_initialize_by(slug:).update!(**attributes, built_in: true)
    end
  end
end
