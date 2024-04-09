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

ActiveRecord::Schema[7.1].define(version: 2024_04_09_133325) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "chunking_profiles", force: :cascade do |t|
    t.string "method"
    t.integer "size"
    t.integer "overlap"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "chunks", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.string "vector_id"
    t.string "content"
    t.jsonb "embeddings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_chunks_on_document_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name"
    t.bigint "user_id", null: false
    t.string "api_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "client_id", null: false
    t.index ["client_id"], name: "index_clients_on_client_id", unique: true
    t.index ["user_id", "name"], name: "index_clients_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "collections", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "conversation_collections", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "collection_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_conversation_collections_on_collection_id"
    t.index ["conversation_id"], name: "index_conversation_collections_on_conversation_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "model_config_id", null: false
    t.boolean "search_collections", default: true
    t.index ["model_config_id"], name: "index_conversations_on_model_config_id"
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.bigint "user_id", null: false
    t.string "filename"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "state"
    t.string "vector_id"
    t.bigint "chunking_profile_id"
    t.index ["chunking_profile_id"], name: "index_documents_on_chunking_profile_id"
    t.index ["collection_id"], name: "index_documents_on_collection_id"
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "conversation_id", null: false
    t.string "author_type"
    t.bigint "author_id", null: false
    t.index ["author_type", "author_id"], name: "index_messages_on_author"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "model_configs", force: :cascade do |t|
    t.string "name"
    t.string "model"
    t.float "temperature"
    t.string "system_prompt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "model_server_id", null: false
    t.boolean "embedding", default: false
    t.index ["model_server_id"], name: "index_model_configs_on_model_server_id"
  end

  create_table "model_servers", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.integer "provider"
    t.boolean "default"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chunks", "documents"
  add_foreign_key "clients", "users"
  add_foreign_key "conversation_collections", "collections"
  add_foreign_key "conversation_collections", "conversations"
  add_foreign_key "conversations", "model_configs"
  add_foreign_key "conversations", "users"
  add_foreign_key "documents", "chunking_profiles"
  add_foreign_key "documents", "collections"
  add_foreign_key "documents", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "model_configs", "model_servers"
end
