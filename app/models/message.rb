class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :author, polymorphic: true
  has_one :user, through: :conversation
  has_many :api_calls, as: :traceable, dependent: :destroy
  has_many :augmentations, dependent: :destroy, class_name: "MessageAugmentation"

  include Turbo::Broadcastable

  after_create_commit lambda {
    broadcast_append_to(
      user_dom_id("conversations"),
      target: "messages",
      partial: "messages/message"
    )

    # conversation.update_list_item
  }
  after_update_commit lambda {
    broadcast_replace_to(
      user_dom_id("conversations"),
      target: "message_#{id}",
      partial: "messages/message"
    )
  }

  def previous(count = 1)
    self.class.where(conversation:).where("id < ?", id).order(id: :asc).last(count)
  end

  def next(count = 1)
    self.class.where(conversation:).where("id > ?", id).order(id: :asc).first(count)
  end
end
