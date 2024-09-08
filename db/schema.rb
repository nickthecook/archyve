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

ActiveRecord::Schema[7.1].define(version: 2024_09_08_165637) do
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

  create_table "api_calls", force: :cascade do |t|
    t.string "service_name"
    t.integer "http_method"
    t.string "url"
    t.jsonb "headers"
    t.jsonb "body"
    t.integer "body_length"
    t.integer "response_code"
    t.jsonb "response_headers"
    t.jsonb "response_body"
    t.integer "response_length"
    t.string "traceable_type"
    t.bigint "traceable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["traceable_type", "traceable_id"], name: "index_api_calls_on_traceable"
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
    t.string "embedding_content"
    t.boolean "entities_extracted", default: false
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
    t.index ["name"], name: "index_clients_on_name", unique: true
    t.index ["user_id", "name"], name: "index_clients_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "collections", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "embedding_model_id", null: false
    t.boolean "graph_enabled", default: false
    t.integer "state", default: 0
    t.integer "process_step"
    t.integer "process_steps"
    t.boolean "stop_jobs", default: false
    t.index ["embedding_model_id"], name: "index_collections_on_embedding_model_id"
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
    t.boolean "stop_jobs", default: false
    t.string "error_message"
    t.index ["chunking_profile_id"], name: "index_documents_on_chunking_profile_id"
    t.index ["collection_id"], name: "index_documents_on_collection_id"
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "graph_entities", force: :cascade do |t|
    t.string "name"
    t.string "entity_type"
    t.bigint "collection_id", null: false
    t.string "summary"
    t.boolean "summary_outdated"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "vector_id"
    t.index ["collection_id"], name: "index_graph_entities_on_collection_id"
  end

  create_table "graph_entity_descriptions", force: :cascade do |t|
    t.bigint "graph_entity_id", null: false
    t.string "description"
    t.bigint "chunk_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chunk_id"], name: "index_graph_entity_descriptions_on_chunk_id"
    t.index ["graph_entity_id"], name: "index_graph_entity_descriptions_on_graph_entity_id"
  end

  create_table "graph_relationships", force: :cascade do |t|
    t.bigint "from_entity_id", null: false
    t.bigint "to_entity_id", null: false
    t.bigint "chunk_id", null: false
    t.integer "strength"
    t.string "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chunk_id"], name: "index_graph_relationships_on_chunk_id"
    t.index ["from_entity_id"], name: "index_graph_relationships_on_from_entity_id"
    t.index ["to_entity_id"], name: "index_graph_relationships_on_to_entity_id"
  end

  create_table "message_augmentations", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.string "augmentation_type", null: false
    t.bigint "augmentation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "distance"
    t.index ["augmentation_type", "augmentation_id"], name: "index_message_augmentations_on_augmentation"
    t.index ["message_id"], name: "index_message_augmentations_on_message_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "conversation_id", null: false
    t.string "author_type"
    t.bigint "author_id", null: false
    t.jsonb "statistics"
    t.jsonb "error"
    t.string "prompt"
    t.string "raw_content"
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
    t.boolean "embedding", default: false
    t.boolean "provisioned", default: false
    t.boolean "available", default: true
    t.string "api_version"
    t.bigint "model_server_id"
    t.index ["model_server_id"], name: "index_model_configs_on_model_server_id"
  end

  create_table "model_servers", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.integer "provider"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "provisioned", default: false
    t.boolean "available", default: true
    t.string "api_key"
  end

  create_table "motor_alert_locks", force: :cascade do |t|
    t.bigint "alert_id", null: false
    t.string "lock_timestamp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_id", "lock_timestamp"], name: "index_motor_alert_locks_on_alert_id_and_lock_timestamp", unique: true
    t.index ["alert_id"], name: "index_motor_alert_locks_on_alert_id"
  end

  create_table "motor_alerts", force: :cascade do |t|
    t.bigint "query_id", null: false
    t.string "name", null: false
    t.text "description"
    t.text "to_emails", null: false
    t.boolean "is_enabled", default: true, null: false
    t.text "preferences", null: false
    t.bigint "author_id"
    t.string "author_type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_alerts_name_unique_index", unique: true, where: "(deleted_at IS NULL)"
    t.index ["query_id"], name: "index_motor_alerts_on_query_id"
    t.index ["updated_at"], name: "index_motor_alerts_on_updated_at"
  end

  create_table "motor_api_configs", force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.text "preferences", null: false
    t.text "credentials", null: false
    t.text "description"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_api_configs_name_unique_index", unique: true, where: "(deleted_at IS NULL)"
  end

  create_table "motor_audits", force: :cascade do |t|
    t.string "auditable_id"
    t.string "auditable_type"
    t.string "associated_id"
    t.string "associated_type"
    t.bigint "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.text "audited_changes"
    t.bigint "version", default: 0
    t.text "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_type", "associated_id"], name: "motor_auditable_associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "motor_auditable_index"
    t.index ["created_at"], name: "index_motor_audits_on_created_at"
    t.index ["request_uuid"], name: "index_motor_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "motor_auditable_user_index"
  end

  create_table "motor_configs", force: :cascade do |t|
    t.string "key", null: false
    t.text "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_motor_configs_on_key", unique: true
    t.index ["updated_at"], name: "index_motor_configs_on_updated_at"
  end

  create_table "motor_dashboards", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.text "preferences", null: false
    t.bigint "author_id"
    t.string "author_type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "motor_dashboards_title_unique_index", unique: true, where: "(deleted_at IS NULL)"
    t.index ["updated_at"], name: "index_motor_dashboards_on_updated_at"
  end

  create_table "motor_forms", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "api_path", null: false
    t.string "http_method", null: false
    t.text "preferences", null: false
    t.bigint "author_id"
    t.string "author_type"
    t.datetime "deleted_at"
    t.string "api_config_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_forms_name_unique_index", unique: true, where: "(deleted_at IS NULL)"
    t.index ["updated_at"], name: "index_motor_forms_on_updated_at"
  end

  create_table "motor_note_tag_tags", force: :cascade do |t|
    t.bigint "tag_id", null: false
    t.bigint "note_id", null: false
    t.index ["note_id", "tag_id"], name: "motor_note_tags_note_id_tag_id_index", unique: true
    t.index ["tag_id"], name: "index_motor_note_tag_tags_on_tag_id"
  end

  create_table "motor_note_tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_note_tags_name_unique_index", unique: true
  end

  create_table "motor_notes", force: :cascade do |t|
    t.text "body"
    t.bigint "author_id"
    t.string "author_type"
    t.string "record_id", null: false
    t.string "record_type", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id", "author_type"], name: "motor_notes_author_id_author_type_index"
    t.index ["record_id", "record_type"], name: "motor_notes_record_id_record_type_index"
  end

  create_table "motor_notifications", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.string "record_id"
    t.string "record_type"
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipient_id", "recipient_type"], name: "motor_notifications_recipient_id_recipient_type_index"
    t.index ["record_id", "record_type"], name: "motor_notifications_record_id_record_type_index"
  end

  create_table "motor_queries", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "sql_body", null: false
    t.text "preferences", null: false
    t.bigint "author_id"
    t.string "author_type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_queries_name_unique_index", unique: true, where: "(deleted_at IS NULL)"
    t.index ["updated_at"], name: "index_motor_queries_on_updated_at"
  end

  create_table "motor_reminders", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.string "author_type", null: false
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.string "record_id"
    t.string "record_type"
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id", "author_type"], name: "motor_reminders_author_id_author_type_index"
    t.index ["recipient_id", "recipient_type"], name: "motor_reminders_recipient_id_recipient_type_index"
    t.index ["record_id", "record_type"], name: "motor_reminders_record_id_record_type_index"
    t.index ["scheduled_at"], name: "index_motor_reminders_on_scheduled_at"
  end

  create_table "motor_resources", force: :cascade do |t|
    t.string "name", null: false
    t.text "preferences", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_motor_resources_on_name", unique: true
    t.index ["updated_at"], name: "index_motor_resources_on_updated_at"
  end

  create_table "motor_taggable_tags", force: :cascade do |t|
    t.bigint "tag_id", null: false
    t.bigint "taggable_id", null: false
    t.string "taggable_type", null: false
    t.index ["tag_id"], name: "index_motor_taggable_tags_on_tag_id"
    t.index ["taggable_id", "taggable_type", "tag_id"], name: "motor_polymorphic_association_tag_index", unique: true
  end

  create_table "motor_tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "motor_tags_name_unique_index", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "key"
    t.jsonb "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_settings_on_user_id"
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
  add_foreign_key "collections", "model_configs", column: "embedding_model_id"
  add_foreign_key "conversation_collections", "collections"
  add_foreign_key "conversation_collections", "conversations"
  add_foreign_key "conversations", "model_configs"
  add_foreign_key "conversations", "users"
  add_foreign_key "documents", "chunking_profiles"
  add_foreign_key "documents", "collections"
  add_foreign_key "documents", "users"
  add_foreign_key "graph_entities", "collections"
  add_foreign_key "graph_entity_descriptions", "chunks"
  add_foreign_key "graph_entity_descriptions", "graph_entities"
  add_foreign_key "graph_relationships", "chunks"
  add_foreign_key "graph_relationships", "graph_entities", column: "from_entity_id"
  add_foreign_key "graph_relationships", "graph_entities", column: "to_entity_id"
  add_foreign_key "message_augmentations", "messages"
  add_foreign_key "messages", "conversations"
  add_foreign_key "model_configs", "model_servers"
  add_foreign_key "motor_alert_locks", "motor_alerts", column: "alert_id"
  add_foreign_key "motor_alerts", "motor_queries", column: "query_id"
  add_foreign_key "motor_note_tag_tags", "motor_note_tags", column: "tag_id"
  add_foreign_key "motor_note_tag_tags", "motor_notes", column: "note_id"
  add_foreign_key "motor_taggable_tags", "motor_tags", column: "tag_id"
  add_foreign_key "settings", "users"
end
