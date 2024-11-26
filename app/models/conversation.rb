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

  scope :chat, -> { where(source: "chat").or(where(source: nil)) }

  include Turbo::Broadcastable

  after_update_commit lambda {
    update_list_item
    update_form
  }

  after_create :add_system_message

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

  private

  def add_system_message
    system_prompt = Setting.find_by(key: 'system_prompt')&.value
    return unless system_prompt

    messages.create!(
      content: system_prompt,
      author: nil
    )
  end
end
