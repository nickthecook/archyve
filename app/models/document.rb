class Document < ApplicationRecord
  belongs_to :collection
  belongs_to :user
  belongs_to :chunking_profile, optional: true
  has_one_attached :file
  has_many :chunks, dependent: :destroy
  has_many :graph_entity_descriptions, dependent: :destroy, through: :chunks
  has_many :chunk_api_calls, through: :chunks, source: :api_calls
  has_many :api_calls, as: :traceable

  include Turbo::Broadcastable
  include AASM

  after_create_commit lambda {
    broadcast_append_to(
      :collections,
      target: "documents",
      partial: "shared/document"
    )
  }
  after_update_commit lambda {
    broadcast_replace_to(
      :collections,
      target: "document_#{id}",
      partial: "shared/document",
      document: reload
    )
    broadcast_replace_to(
      :documents,
      target: "document_#{id}-details",
      partial: "documents/document"
    )

    collection.touch(:updated_at)
  }
  after_destroy_commit lambda {
    broadcast_remove_to(
      :collections,
      target: "document_#{id}"
    )
  }

  enum state: {
    created: 0,
    chunking: 4,
    chunked: 1,
    deleting: 7,
    stopped: 8,
    errored: 10,
  }

  # rubocop:disable Metrics/BlockLength
  aasm column: :state, enum: true do
    state :created
    state :chunking
    state :chunked
    state :deleting
    state :errored
    state :stopped

    event :reset do
      # TODO: validate that there are no chunks in the db
      transitions to: :created
    end

    event :chunking do
      transitions from: :created, to: :chunking
    end
    event :chunk do
      transitions from: :chunking, to: :chunked
    end
    event :embedding do
      transitions from: :chunked, to: :embedding
    end
    event :embed do
      transitions from: :embedding, to: :embedded
    end
    event :extract do
      transitions from: :embedded, to: :extracting
    end
    event :extracted do
      transitions from: :extracting, to: :extracted
    end

    event :deleting do
      transitions to: :deleting
    end
    event :error do
      transitions to: :errored
    end
    event :stop do
      transitions to: :stopped
    end
  end
  # rubocop:enable Metrics/BlockLength

  def contents
    file.download
  end

  def embedded?
    chunks.embedded.count == chunks.count
  end

  def extracted?
    chunks.extracted.count == chunks.count
  end
end
