class Conversation < ApplicationRecord
  belongs_to :user
  belongs_to :model_config
  has_many :messages, dependent: :destroy
  has_many :conversation_collections
  has_many :collections, through: :conversation_collections, dependent: :destroy
end
