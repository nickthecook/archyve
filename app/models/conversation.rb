class Conversation < ApplicationRecord
  belongs_to :user
  belongs_to :model_config
  has_many :messages, dependent: :destroy
  has_many :conversation_collections, dependent: :destroy
  has_many :collections, through: :conversation_collections, dependent: :destroy
  has_many :api_calls, as: :traceable, dependent: :destroy

  attribute :source, :integer, default: 0
  enum source: {
    chat: 0,
    api: 1,
    proxy: 2,
  }

  scope :chat, -> { where(source: "chat") }

  include Turbo::Broadcastable

  after_update_commit lambda {
    update_list_item
    update_form
  }

  def update_list_item
    broadcast_replace_to(
      user_dom_id("conversations"),
      target: dom_id,
      partial: "conversations/conversation_list_item",
      locals: { conversation: self, selected: self }
    )
  end

  def update_form
    broadcast_replace_to(
      user_dom_id("conversations"),
      target: "conversation_form",
      partial: "conversations/conversation_form",
      current_user: user
    )
  end
end
