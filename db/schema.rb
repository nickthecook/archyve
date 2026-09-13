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

ActiveRecord::Schema[8.1].define(version: 2026_09_13_131645) do
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
    t.string "origin", null: false
    t.datetime "removed_at"
    t.datetime "updated_at", null: false
    t.index ["collection_id", "document_id"], name: "index_collection_memberships_on_collection_id_and_document_id", unique: true
    t.index ["collection_id", "removed_at"], name: "index_collection_memberships_on_collection_id_and_removed_at"
    t.index ["collection_id"], name: "index_collection_memberships_on_collection_id"
    t.index ["document_id"], name: "index_collection_memberships_on_document_id"
  end

  create_table "collection_users", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.datetime "created_at", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["collection_id", "user_id"], name: "index_collection_users_on_collection_id_and_user_id", unique: true
    t.index ["collection_id"], name: "index_collection_users_on_collection_id"
    t.index ["user_id"], name: "index_collection_users_on_user_id"
  end

  create_table "collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_collections_on_slug", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "inference_model_id"
    t.jsonb "scope", default: {}, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["inference_model_id"], name: "index_conversations_on_inference_model_id"
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.bigint "source_id", null: false
    t.jsonb "source_metadata", default: {}, null: false
    t.bigint "source_sync_id"
    t.string "source_version"
    t.string "status", default: "pending", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["source_id", "external_id"], name: "index_documents_on_source_id_and_external_id", unique: true
    t.index ["source_id"], name: "index_documents_on_source_id"
    t.index ["source_sync_id"], name: "index_documents_on_source_sync_id"
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

  create_table "hits", force: :cascade do |t|
    t.bigint "chunk_id"
    t.datetime "created_at", null: false
    t.float "distance", null: false
    t.bigint "document_id"
    t.string "document_title", null: false
    t.integer "handle", null: false
    t.string "heading_path"
    t.float "score", null: false
    t.bigint "segment_id", null: false
    t.text "snippet", null: false
    t.datetime "updated_at", null: false
    t.index ["chunk_id"], name: "index_hits_on_chunk_id"
    t.index ["document_id"], name: "index_hits_on_document_id"
    t.index ["segment_id", "handle"], name: "index_hits_on_segment_id_and_handle", unique: true
    t.index ["segment_id"], name: "index_hits_on_segment_id"
  end

  create_table "inference_models", force: :cascade do |t|
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.integer "dimensions"
    t.string "display_name"
    t.boolean "enabled", default: true, null: false
    t.bigint "inference_server_id", null: false
    t.integer "kind", default: 0, null: false
    t.string "name", null: false
    t.boolean "preferred", default: false, null: false
    t.boolean "supports_tools", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["inference_server_id", "name"], name: "index_inference_models_on_inference_server_id_and_name", unique: true
    t.index ["inference_server_id"], name: "index_inference_models_on_inference_server_id"
    t.index ["kind"], name: "index_inference_models_on_single_embedding", unique: true, where: "(kind = 1)"
    t.index ["preferred"], name: "index_inference_models_on_preferred_chat", unique: true, where: "(preferred AND (kind = 0))"
  end

  create_table "inference_servers", force: :cascade do |t|
    t.text "api_key"
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "last_check_error"
    t.string "last_check_status"
    t.datetime "last_checked_at"
    t.string "name", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_inference_servers_on_name", unique: true
    t.index ["type"], name: "index_inference_servers_on_type"
  end

  create_table "messages", force: :cascade do |t|
    t.datetime "completed_at"
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "error"
    t.bigint "inference_model_id"
    t.integer "position", null: false
    t.integer "role", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "position"], name: "index_messages_on_conversation_id_and_position", unique: true
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["inference_model_id"], name: "index_messages_on_inference_model_id"
  end

  create_table "segments", force: :cascade do |t|
    t.integer "candidate_count"
    t.text "content"
    t.datetime "created_at", null: false
    t.string "failure_kind"
    t.integer "kind", null: false
    t.bigint "message_id", null: false
    t.integer "position", null: false
    t.jsonb "queries", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "position"], name: "index_segments_on_message_id_and_position", unique: true
    t.index ["message_id"], name: "index_segments_on_message_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "source_collections", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.datetime "created_at", null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_source_collections_on_collection_id"
    t.index ["source_id", "collection_id"], name: "index_source_collections_on_source_id_and_collection_id", unique: true
    t.index ["source_id"], name: "index_source_collections_on_source_id"
  end

  create_table "source_syncs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_count", default: 0, null: false
    t.text "error"
    t.integer "failed_count", default: 0, null: false
    t.datetime "finished_at"
    t.integer "found_count", default: 0, null: false
    t.integer "removed_count", default: 0, null: false
    t.integer "skipped_count", default: 0, null: false
    t.bigint "source_id", null: false
    t.integer "stale_count", default: 0, null: false
    t.datetime "started_at", null: false
    t.string "status", default: "running", null: false
    t.integer "unchanged_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "updated_count", default: 0, null: false
    t.index ["source_id", "started_at"], name: "index_source_syncs_on_source_id_and_started_at"
    t.index ["source_id"], name: "index_source_syncs_on_source_id"
  end

  create_table "source_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "role", default: 1, null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["source_id", "user_id"], name: "index_source_users_on_source_id_and_user_id", unique: true
    t.index ["source_id"], name: "index_source_users_on_source_id"
    t.index ["user_id"], name: "index_source_users_on_user_id"
  end

  create_table "sources", force: :cascade do |t|
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.jsonb "state", default: {}, null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["type"], name: "index_sources_on_type"
    t.index ["user_id"], name: "index_manual_upload_sources_on_user_id", unique: true, where: "((type)::text = 'Sources::ManualUpload'::text)"
    t.index ["user_id"], name: "index_sources_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chunks", "documents"
  add_foreign_key "collection_memberships", "collections"
  add_foreign_key "collection_memberships", "documents"
  add_foreign_key "collection_users", "collections"
  add_foreign_key "collection_users", "users"
  add_foreign_key "conversations", "inference_models", on_delete: :nullify
  add_foreign_key "conversations", "users"
  add_foreign_key "documents", "source_syncs", on_delete: :nullify
  add_foreign_key "documents", "sources"
  add_foreign_key "embeddings", "chunks"
  add_foreign_key "hits", "chunks", on_delete: :nullify
  add_foreign_key "hits", "documents", on_delete: :nullify
  add_foreign_key "hits", "segments"
  add_foreign_key "inference_models", "inference_servers"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "inference_models", on_delete: :nullify
  add_foreign_key "segments", "messages"
  add_foreign_key "sessions", "users"
  add_foreign_key "source_collections", "collections"
  add_foreign_key "source_collections", "sources"
  add_foreign_key "source_syncs", "sources"
  add_foreign_key "source_users", "sources"
  add_foreign_key "source_users", "users"
  add_foreign_key "sources", "users", on_delete: :nullify
end
