class Collection < ApplicationRecord
  has_many :documents, dependent: :destroy
  has_many :conversation_collections, dependent: :destroy
  belongs_to :embedding_model, class_name: "ModelConfig"
  has_many :graph_entities, dependent: :destroy

  after_create_commit lambda {
    broadcast_append_to(
      :collections,
      target: "collection_list_items",
      partial: "shared/collection_list_item",
      locals: {
        collection: self,
        selected: false,
      }
    )
  }
  after_update_commit lambda {
    broadcast_replace_to(
      :collections,
      target: "collection_#{id}_list_item",
      partial: "shared/collection_list_item",
      locals: {
        collection: self,
        selected: false,
      }
    )
    broadcast_replace_to(
      :collections,
      target: "collection_#{id}",
      partial: "collections/collection",
      locals: {
        collection: self,
        selected: false,
      }
    )
  }
  after_destroy_commit lambda {
    broadcast_remove_to(
      :collections,
      target: "collection_#{id}_list_item"
    )
  }

  enum state: {
    created: 0,
    summarizing: 1,
    summarized: 2,
    graphing: 3,
    graphed: 4,
    deleting: 10,
    errored: 20,
  }

  def generate_slug
    update!(slug: "#{id}-#{name.parameterize}")
  end
end
