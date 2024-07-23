class Collection < ApplicationRecord
  has_many :documents, dependent: :destroy
  has_many :conversation_collections, dependent: :destroy
  belongs_to :embedding_model, class_name: "ModelConfig"
  has_many :entities, dependent: :destroy
  has_many :relationships, through: :entities

  after_create_commit lambda {
    broadcast_append_to(
      :collections,
      target: "collection_list_items",
      partial: "shared/collection_list_item",
      collection: @collection,
      selected: false
    )
  }
  after_update_commit lambda {
    broadcast_replace_to(
      :collections,
      target: "collection_#{@id}_list_item",
      partial: "shared/collection_list_item",
      collection: @collection,
      selected: false
    )
  }
  after_destroy_commit lambda {
    broadcast_remove_to(
      :collections,
      target: "collection_#{@id}_list_item"
    )
  }

  def generate_slug
    update!(slug: "#{id}-#{name.parameterize}")
  end
end
