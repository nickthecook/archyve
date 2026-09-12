class CreateChat < ActiveRecord::Migration[8.1]
  def change
    # A chat with the archive. Its retrieval scope is fixed for its lifetime —
    # changing what you're drawing on means starting a new conversation — so it
    # lives here rather than on a message.
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true, index: true

      # Which model answered. Nullified rather than cascading if the model row
      # goes away: a transcript is a record of what happened, and deleting a
      # model from Settings must not delete the conversations it took part in.
      t.references :inference_model, foreign_key: { on_delete: :nullify }

      t.string :title

      # The c[]/doc spec, stored in the same shape the search URL uses so one
      # encoding covers the search box, the chat, and the link between them.
      # Deliberately *not* a resolved list of document ids — it is re-resolved
      # on every retrieval, which is what makes a revoked grant take effect
      # mid-conversation and a newly-filed document become searchable.
      t.jsonb :scope, null: false, default: {}

      t.timestamps
    end

    # One turn. Carries no text of its own: a user turn is a message with a
    # single text segment, exactly like an assistant turn that didn't search.
    # The alternative — text on the message for users, segments for assistants —
    # buys nothing and costs a dual-purpose column and a second render path.
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.integer :role, null: false # see Message.roles
      t.integer :position, null: false
      t.timestamps
    end
    add_index :messages, [:conversation_id, :position], unique: true

    # One contiguous piece of a turn, in the order it was produced. A reply that
    # searches is three segments — prose, retrieval, prose — and storing them
    # in order is what lets the transcript show the pause where it happened
    # instead of tidying it away.
    create_table :segments do |t|
      t.references :message, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :kind, null: false # see Segment.kinds

      # Text segments only.
      t.text :content

      # Retrieval segments only. All the queries went out in one tool call, so
      # they belong to the segment rather than to individual hits — which is
      # also why nothing records which query found which hit. Promote Query to
      # a model if that ever needs answering.
      t.jsonb :queries, null: false, default: []

      # The pool the hits were chosen from, before fusion truncated it: the
      # "of 41" in the collapsed panel.
      t.integer :candidate_count

      # Set only when retrieval couldn't run — "not_configured" or
      # "unreachable", matching Retrieval::Failure#kind. A retrieval segment
      # with no hits and no failure means the search ran and found nothing,
      # which is a different thing to say and must stay distinguishable.
      t.string :failure_kind

      t.timestamps
    end
    add_index :segments, [:message_id, :position], unique: true

    # One chunk the model was shown, as it was shown to it.
    create_table :hits do |t|
      t.references :segment, null: false, foreign_key: true

      # What the model cites — "1", "2" — and the only name it is ever given
      # for a source. Positional within this segment, so it is not unique
      # anywhere else. The model cites the handle and Archyve resolves it to a
      # link, which is why it can neither author a URL nor invent a document.
      t.integer :handle, null: false

      # Nullified, never cascaded: reingesting a document destroys its chunks
      # and makes new ones, and a chat from last week must not lose its
      # citations because a source synced. Present, these power the link and
      # the chunk inspector; gone, the snippet below still shows what the
      # answer was based on.
      t.references :chunk, foreign_key: { on_delete: :nullify }
      t.references :document, foreign_key: { on_delete: :nullify }

      # Cosine distance and the fused rank score. Both, because they answer
      # different questions: distance is read as a percentage and says whether
      # the archive had anything good, score is what the ordering is by. See
      # Retrieval::Fuse.
      t.float :distance, null: false
      t.float :score, null: false

      # What the model actually read, denormalized on purpose. The transcript
      # is a historical record and the corpus is not — reading through to the
      # chunk would silently rewrite history the next time a source syncs. The
      # title is copied for the same reason the snippet is: a citation that
      # renders as "a document since removed" has lost the one thing a reader
      # needed from it.
      t.text :snippet, null: false
      t.string :document_title, null: false
      t.string :heading_path

      t.timestamps
    end
    add_index :hits, [:segment_id, :handle], unique: true
  end
end
