class ConversationCollection < ApplicationRecord
  belongs_to :conversation
  belongs_to :collection
end
