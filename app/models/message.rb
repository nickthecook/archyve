class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :author, polymorphic: true

  # has_rich_text :content
end
 