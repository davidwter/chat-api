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

ActiveRecord::Schema[7.0].define(version: 2024_12_19_100629) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "categories_connectors", force: :cascade do |t|
    t.bigint "connector_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_categories_connectors_on_category_id"
    t.index ["connector_id", "category_id"], name: "index_categories_connectors_on_connector_id_and_category_id", unique: true
    t.index ["connector_id"], name: "index_categories_connectors_on_connector_id"
  end

  create_table "connector_mentions", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "connector_id", null: false
    t.decimal "confidence_score", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confidence_score"], name: "index_connector_mentions_on_confidence_score"
    t.index ["connector_id"], name: "index_connector_mentions_on_connector_id"
    t.index ["message_id", "connector_id"], name: "index_connector_mentions_on_message_id_and_connector_id", unique: true
    t.index ["message_id"], name: "index_connector_mentions_on_message_id"
  end

  create_table "connectors", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_connectors_on_name", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.string "title"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_conversations_on_created_at"
    t.index ["status"], name: "index_conversations_on_status"
  end

  create_table "messages", force: :cascade do |t|
    t.text "content", null: false
    t.boolean "is_user", default: false
    t.string "message_type", default: "text"
    t.string "status", default: "sent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "conversation_id"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["created_at"], name: "index_messages_on_created_at"
    t.index ["is_user"], name: "index_messages_on_is_user"
  end

  add_foreign_key "categories_connectors", "categories"
  add_foreign_key "categories_connectors", "connectors"
  add_foreign_key "connector_mentions", "connectors"
  add_foreign_key "connector_mentions", "messages"
  add_foreign_key "messages", "conversations"
end
