class Conversation < ApplicationRecord
  belongs_to :user
  belongs_to :model_config
  has_many :messages
end
