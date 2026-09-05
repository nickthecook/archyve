# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_04_120700) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "chunks", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.integer "position", null: false
    t.jsonb "structure", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "position"], name: "index_chunks_on_document_id_and_position", unique: true
    t.index ["document_id"], name: "index_chunks_on_document_id"
  end

  create_table "collection_memberships", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.datetime "removed_at"
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id", "document_id"], name: "index_collection_memberships_on_collection_id_and_document_id", unique: true
    t.index ["collection_id", "removed_at"], name: "index_collection_memberships_on_collection_id_and_removed_at"
    t.index ["collection_id"], name: "index_collection_memberships_on_collection_id"
    t.index ["document_id"], name: "index_collection_memberships_on_document_id"
  end

  create_table "collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_collections_on_slug", unique: true
  end

  create_table "connector_collections", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.bigint "connector_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_connector_collections_on_collection_id"
    t.index ["connector_id", "collection_id"], name: "index_connector_collections_on_connector_id_and_collection_id", unique: true
    t.index ["connector_id"], name: "index_connector_collections_on_connector_id"
  end

  create_table "connectors", force: :cascade do |t|
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.jsonb "state", default: {}, null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["type"], name: "index_connectors_on_type"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "connector_id", null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.jsonb "source_metadata", default: {}, null: false
    t.string "source_version"
    t.string "status", default: "pending", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["connector_id", "external_id"], name: "index_documents_on_connector_id_and_external_id", unique: true
    t.index ["connector_id"], name: "index_documents_on_connector_id"
    t.index ["status"], name: "index_documents_on_status"
  end

  create_table "embeddings", force: :cascade do |t|
    t.bigint "chunk_id", null: false
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 768
    t.string "embedding_model", null: false
    t.datetime "updated_at", null: false
    t.index ["chunk_id", "embedding_model"], name: "index_embeddings_on_chunk_id_and_embedding_model", unique: true
    t.index ["chunk_id"], name: "index_embeddings_on_chunk_id"
    t.index ["embedding"], name: "index_embeddings_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
  end

  add_foreign_key "chunks", "documents"
  add_foreign_key "collection_memberships", "collections"
  add_foreign_key "collection_memberships", "documents"
  add_foreign_key "connector_collections", "collections"
  add_foreign_key "connector_collections", "connectors"
  add_foreign_key "documents", "connectors"
  add_foreign_key "embeddings", "chunks"
end
