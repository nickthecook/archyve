class RenameMaxToolRoundsSetting < ActiveRecord::Migration[8.0]
  # chat.max_tool_rounds capped search and read together; it now caps search
  # alone. Carried over rather than dropped so an admin who raised it keeps the
  # value — Setting would otherwise ignore the orphaned row and silently revert
  # to the default. Raw SQL because the model no longer accepts the old key.
  def up
    execute("UPDATE settings SET key = 'chat.max_search_rounds' WHERE key = 'chat.max_tool_rounds'")
  end

  def down
    execute("UPDATE settings SET key = 'chat.max_tool_rounds' WHERE key = 'chat.max_search_rounds'")
  end
end
