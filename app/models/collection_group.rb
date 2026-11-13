class CollectionGroup < ApplicationRecord
  include Grantable

  belongs_to :collection
  belongs_to :group

  validates :group_id, uniqueness: { scope: :collection_id }
end
