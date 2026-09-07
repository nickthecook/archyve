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

ActiveRecord::Schema[8.1].define(version: 2026_09_07_013751) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "connector_syncs", force: :cascade do |t|
    t.bigint "connector_id", null: false
    t.datetime "created_at", null: false
    t.integer "created_count", default: 0, null: false
    t.text "error"
    t.integer "failed_count", default: 0, null: false
    t.datetime "finished_at"
    t.integer "found_count", default: 0, null: false
    t.integer "removed_count", default: 0, null: false
    t.integer "skipped_count", default: 0, null: false
    t.integer "stale_count", default: 0, null: false
    t.datetime "started_at", null: false
    t.string "status", default: "running", null: false
    t.integer "unchanged_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "updated_count", default: 0, null: false
    t.index ["connector_id", "started_at"], name: "index_connector_syncs_on_connector_id_and_started_at"
    t.index ["connector_id"], name: "index_connector_syncs_on_connector_id"
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
    t.bigint "connector_sync_id"
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
    t.index ["connector_sync_id"], name: "index_documents_on_connector_sync_id"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chunks", "documents"
  add_foreign_key "collection_memberships", "collections"
  add_foreign_key "collection_memberships", "documents"
  add_foreign_key "connector_collections", "collections"
  add_foreign_key "connector_collections", "connectors"
  add_foreign_key "connector_syncs", "connectors"
  add_foreign_key "documents", "connector_syncs", on_delete: :nullify
  add_foreign_key "documents", "connectors"
  add_foreign_key "embeddings", "chunks"
end
