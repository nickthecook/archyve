class Document < ApplicationRecord
  belongs_to :collection
  belongs_to :user
  has_one_attached :file
end
