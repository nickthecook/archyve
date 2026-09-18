class AddEndpointToSources < ActiveRecord::Migration[8.1]
  def change
    # Nullable, and it stays nullable: Folder reads a path on the local disk and
    # ManualUpload is fed by a person, so neither has a remote host to name.
    # No cascade — see the `restrict_with_error` on Endpoint.
    add_reference :sources, :endpoint, null: true, foreign_key: true
  end
end
