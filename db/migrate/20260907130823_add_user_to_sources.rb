class AddUserToSources < ActiveRecord::Migration[8.1]
  def change
    # Nullable, and nullified rather than cascaded when the user goes: a source
    # owns its documents (`has_many :documents, dependent: :destroy`), so
    # deleting a departing employee must not take every document they uploaded —
    # plus its chunks and embeddings — with them. An unowned upload source stays
    # for an admin to reassign or delete deliberately.
    add_reference :sources, :user, null: true, foreign_key: { on_delete: :nullify }

    # One upload source per person. Partial, because only manual upload is
    # per-user; folders and the rest are shared and carry no owner. NULLs don't
    # collide in a Postgres unique index, so orphaned sources coexist fine.
    add_index :sources, :user_id,
      unique: true,
      where: "type = 'Sources::ManualUpload'",
      name: "index_manual_upload_sources_on_user_id"
  end
end
