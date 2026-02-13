class Document < ApplicationRecord
  belongs_to :collection
  belongs_to :user
  belongs_to :chunking_profile, optional: true
  belongs_to :parent, optional: true, class_name: "Document"
  has_one_attached :file
  has_many :chunks, dependent: :destroy
  has_many :graph_entity_descriptions, dependent: :destroy, through: :chunks
  has_many :chunk_api_calls, through: :chunks, source: :api_calls
  has_many :api_calls, as: :traceable, dependent: :destroy
  has_many :children, class_name: "Document", inverse_of: :parent, dependent: :destroy

  include Turbo::Broadcastable
  include AASM

  after_create_commit lambda {
    if parent
      parent.broadcast_replace
    else
      broadcast_append_to(
        :collections,
        target: "collection_#{collection.id}-documents",
        partial: "collections/document",
        locals: { document: self }
      )
    end
  }
  after_update_commit lambda {
    who = parent || self
    who.broadcast_replace
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
    fetching: 2,
    fetched: 3,
    chunking: 4,
    chunked: 1,
    converting: 5,
    converted: 6,
    deleting: 7,
    stopped: 8,
    errored: 10,
  }

  # rubocop:disable Metrics/BlockLength
  aasm column: :state, enum: true do
    state :created
    state :fetching
    state :fetched
    state :converting
    state :converted
    state :chunking
    state :chunked
    state :deleting
    state :errored
    state :stopped

    event :reset do
      # TODO: validate that there are no chunks in the db
      transitions to: :created
    end
    event :converting do
      transitions from: :created, to: :converting
    end
    event :convert do
      transitions from: :converting, to: :converted
    end
    event :chunking do
      transitions from: [:converted, :created], to: :chunking
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
      transitions from: [:embedded, :converted], to: :extracting
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

  def web?
    link.present?
  end

  def no_children?
    children.empty?
  end

  def original_document?
    parent.nil?
  end

  delegate :content_type, to: :file

  def parser
    Parsers.parser_for(filename, content_type).new(self)
  end

  def image?
    content_type&.starts_with?("image/")
  end

  def audio?
    content_type&.starts_with?("audio/")
  end

  def video?
    content_type&.starts_with?("video/")
  end

  def original_document
    return self if parent.nil?

    parent.original_document
  end

  protected

  def broadcast_replace
    broadcast_replace_to(
      :collections,
      target: "document_#{id}",
      partial: "collections/document",
      locals: { document: self }
    )
  end
end
