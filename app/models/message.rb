class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :author, polymorphic: true
  has_one :user, through: :conversation

  include Turbo::Broadcastable

  after_create_commit lambda {
    broadcast_append_to(
      user_dom_id("conversations"),
      target: "messages",
      partial: "messages/message"
    )
  }
  after_update_commit lambda {
    broadcast_replace_to(
      user_dom_id("conversations"),
      target: "message_#{id}",
      partial: "messages/message"
    )
  }
end
