class AddInferenceModelToMessages < ActiveRecord::Migration[8.1]
  def change
    # Which model produced this turn. The conversation already names the model
    # it is *currently* set to, but that is a setting the person asking can
    # change mid-chat — so it can't answer "what wrote this answer?" about a
    # turn from ten minutes ago. Recorded per turn, it can.
    #
    # Nullify rather than cascade, like conversations: an admin removing a model
    # must not delete the transcript of what it said, and a turn whose model row
    # is gone is still a true record of what was said.
    add_reference :messages, :inference_model, foreign_key: { on_delete: :nullify }
  end
end
