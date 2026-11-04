class AgentCollection < ApplicationRecord
  belongs_to :agent
  belongs_to :collection

  validates :collection_id, uniqueness: { scope: :agent_id }
end
