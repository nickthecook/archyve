class Message < ApplicationRecord
  belongs_to :conversation, counter_cache: true
  belongs_to :author, polymorphic: true, optional: true
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

    conversation.update_list_item
  }
  after_update_commit lambda {
    broadcast_replace_to(
      user_dom_id("conversations"),
      target: "message_#{id}",
      partial: "messages/message"
    )
  }
  after_destroy_commit lambda {
    broadcast_remove_to(user_dom_id("conversations"), target: "message_#{id}")
  }

  def previous(count = 1)
    previous = self.class.where(conversation:).where("id < ?", id).order(id: :asc).last(count)
    return previous.first if count == 1

    previous
  end

  def next(count = 1)
    nnext = self.class.where(conversation:).where("id > ?", id).order(id: :asc).first(count)
    return nnext.first if count == 1

    nnext
  end

  def system?
    author_id.nil?
  end

  delegate :user, to: :conversation
end
