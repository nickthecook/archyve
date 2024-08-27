class MessageAugmentation < ApplicationRecord
  belongs_to :message
  belongs_to :augmentation, polymorphic: true

  include Turbo::Broadcastable

  after_create_commit lambda {
    if augmentation_type == "Chunk"
      broadcast_append_to(
        user_dom_id("conversations"),
        target: "message_#{message.id}-augmentations",
        partial: "messages/chunk",
        locals: {
          chunk: augmentation,
          distance:,
        }
      )
    elsif augmentation_type == "GraphEntity"
      broadcast_append_to(
        user_dom_id("conversations"),
        target: "message_#{message.id}-augmentations",
        partial: "messages/entity",
        locals: {
          entity: augmentation,
          distance:,
        }
      )
    end
  }

  private

  def user
    message.user
  end

  def partial
    case augmentation_type
    when "Chunk"
      "messages/chunk"
    when "GraphEntity"
      "messages/entity"
    end
  end
end
