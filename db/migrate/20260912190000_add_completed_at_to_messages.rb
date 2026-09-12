class AddCompletedAtToMessages < ActiveRecord::Migration[8.1]
  def up
    # When the turn stopped producing. Without it the page cannot tell "still
    # working" from "finished", and has to guess from whether any content
    # exists — which is wrong the moment a turn has a retrieval segment and is
    # waiting on the model's second pass. That wait is the longest part of a
    # turn and the one most in need of a spinner.
    add_column :messages, :completed_at, :datetime

    # Everything already on disk is finished by definition; nothing is mid-turn
    # across a deploy. Left null, old turns would spin for good.
    execute "UPDATE messages SET completed_at = updated_at"
  end

  def down
    remove_column :messages, :completed_at
  end
end
