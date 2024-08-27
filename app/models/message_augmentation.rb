class MessageAugmentation < ApplicationRecord
  belongs_to :message
  belongs_to :augmentation, polymorphic: true
end
