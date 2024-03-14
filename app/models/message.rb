class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :author, polymorphic: true

  include Turbo::Broadcastable

  after_create_commit -> { 
    broadcast_append_to(
      :conversations,
      target: "messages",
      partial: "messages/message"
    )
  }
  after_update_commit -> { 
    broadcast_replace_to(
      :conversations,
      target: "message_#{id}",
      partial: "messages/message"
    )
  }
end
 