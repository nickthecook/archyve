# One person's access to one agent in granted mode, on the same ladder as
# collection grants: accessor chats, editor sets its collections, manager does
# the rest. The global role is still the ceiling — see User#grant_on.
class AgentUser < ApplicationRecord
  include Grantable

  belongs_to :agent
  belongs_to :user

  validates :user_id, uniqueness: { scope: :agent_id }
end
