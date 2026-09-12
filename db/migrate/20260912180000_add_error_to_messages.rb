class AddErrorToMessages < ActiveRecord::Migration[8.1]
  def change
    # Why a turn stopped early, when it stopped for a reason that isn't the
    # model's to explain — an unreachable chat server, a model that turned out
    # not to support tools. Distinct from Segment#failure_kind, which is a
    # *retrieval* that failed inside an otherwise working turn.
    #
    # Without this the only way to show a broken turn would be to write the
    # apology into a text segment, which puts words in the model's mouth and
    # makes a transport failure indistinguishable from something it said.
    add_column :messages, :error, :string
  end
end
