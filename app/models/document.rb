class Document < ApplicationRecord
  belongs_to :collection
  belongs_to :user
  belongs_to :chunking_profile, optional: true
  has_one_attached :file
  has_many :chunks, dependent: :destroy

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
      document: @document
    )
    broadcast_replace_to(
      :documents,
      target: "document_#{id}-details",
      partial: "documents/document"
    )
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
    embedding: 5,
    embedded: 2,
    storing: 6,
    stored: 3,
    deleting: 7,
    errored: 10,
  }

  # rubocop:disable Metrics/BlockLength
  aasm column: :state, enum: true do
    state :created
    state :chunking
    state :chunked
    state :embedding
    state :embedded
    state :storing
    state :stored
    state :deleting
    state :errored

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
    event :storing do
      transitions from: :embedded, to: :storing
    end
    event :store do
      transitions from: :storing, to: :stored
    end

    event :deleting do
      transitions to: :deleting
    end
    event :error do
      transitions to: :errored
    end
  end
  # rubocop:enable Metrics/BlockLength

  def contents
    file.download
  end
end
