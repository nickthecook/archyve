class Conversation < ApplicationRecord
  belongs_to :user
  belongs_to :model_config
  has_many :messages, dependent: :destroy
  has_many :conversation_collections, dependent: :destroy
  has_many :collections, through: :conversation_collections, dependent: :destroy

  include Turbo::Broadcastable

  after_update_commit -> {
    broadcast_replace_to(
      user_dom_id("conversations"),
      target: dom_id,
      partial: "conversations/conversation_list_item",
      locals: { selected: self}
    )
  }
end
