class Relationship < ApplicationRecord
  belongs_to :from, class_name: 'Entity'
  belongs_to :to, class_name: 'Entity'
  belongs_to :chunk
end
