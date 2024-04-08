class AddChunkingProfileToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_reference :documents, :chunking_profile, null: true, foreign_key: true

    profile = ChunkingProfile.create!(
      method: :bytes,
      size: 120,
      overlap: 20,
    )

    Document.update_all(chunking_profile_id: profile.id)
  end
end
