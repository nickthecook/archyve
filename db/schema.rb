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

ActiveRecord::Schema[7.1].define(version: 2024_03_16_010656) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "conversations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "model_config_id", null: false
    t.index ["model_config_id"], name: "index_conversations_on_model_config_id"
    t.index ["user_id"], name: "index_conversations_on_user_id"
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

  add_foreign_key "conversations", "model_configs"
  add_foreign_key "conversations", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "model_configs", "model_servers"
end
