class SourceGroup < ApplicationRecord
  include Grantable

  belongs_to :source
  belongs_to :group

  validates :group_id, uniqueness: { scope: :source_id }
end
