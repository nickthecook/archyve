class Message < ApplicationRecord
  belongs_to :user
  belongs_to :conversation

  # has_rich_text :content
end
 