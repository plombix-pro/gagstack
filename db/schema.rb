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

ActiveRecord::Schema[8.1].define(version: 2026_07_16_133401) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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

  create_table "announcements", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "token_digest", null: false
    t.string "token_hash"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_hash"], name: "index_api_tokens_on_token_hash", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.integer "posts_count", default: 0, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_categories_on_position"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "comment_votes", force: :cascade do |t|
    t.bigint "comment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "upvoted", null: false
    t.bigint "user_id", null: false
    t.index ["comment_id"], name: "index_comment_votes_on_comment_id"
    t.index ["user_id", "comment_id"], name: "index_comment_votes_on_user_id_and_comment_id", unique: true
    t.index ["user_id"], name: "index_comment_votes_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.string "ancestry"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "downvotes_count", default: 0
    t.boolean "hidden", default: false, null: false
    t.bigint "post_id", null: false
    t.datetime "updated_at", null: false
    t.integer "upvotes_count", default: 0
    t.bigint "user_id", null: false
    t.index ["ancestry"], name: "index_comments_on_ancestry"
    t.index ["post_id", "ancestry"], name: "index_comments_on_post_id_and_ancestry"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "flags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "flaggable_id"
    t.string "flaggable_type"
    t.bigint "post_id"
    t.text "reason", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["flaggable_type", "flaggable_id"], name: "index_flags_on_flaggable_type_and_flaggable_id"
    t.index ["post_id"], name: "index_flags_on_post_id"
    t.index ["status", "created_at"], name: "index_flags_on_status_and_created_at"
    t.index ["user_id"], name: "index_flags_on_user_id"
  end

  create_table "moderation_logs", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}
    t.bigint "moderator_id", null: false
    t.integer "target_id"
    t.string "target_type"
    t.datetime "updated_at", null: false
    t.index ["moderator_id"], name: "index_moderation_logs_on_moderator_id"
    t.index ["target_type", "target_id"], name: "index_moderation_logs_on_target_type_and_target_id"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.integer "comments_count", default: 0
    t.datetime "created_at", null: false
    t.integer "downvotes_count", default: 0
    t.float "hotness", default: 0.0
    t.string "media_type", null: false
    t.string "perceptual_hash"
    t.string "slug", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.float "trending_score", default: 0.0
    t.datetime "updated_at", null: false
    t.integer "upvotes_count", default: 0
    t.bigint "user_id", null: false
    t.integer "views_count", default: 0
    t.index ["category_id", "created_at"], name: "index_posts_on_category_id_and_created_at"
    t.index ["category_id", "hotness"], name: "index_posts_on_category_id_and_hotness"
    t.index ["category_id"], name: "index_posts_on_category_id"
    t.index ["perceptual_hash"], name: "index_posts_on_perceptual_hash"
    t.index ["slug"], name: "index_posts_on_slug", unique: true
    t.index ["status", "category_id"], name: "index_posts_on_status_and_category_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "reputation_thresholds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "min_reputation", default: 1, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_reputation_thresholds_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "banned_at"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "email_address", null: false
    t.string "email_change_token"
    t.datetime "email_change_token_expires_at"
    t.integer "flags_count", default: 0
    t.datetime "last_email_changed_at"
    t.string "password_digest", null: false
    t.integer "reputation", default: 1, null: false
    t.string "role", default: "user", null: false
    t.string "slug"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "verification_token"
    t.datetime "verified_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["email_change_token"], name: "index_users_on_email_change_token"
    t.index ["slug"], name: "index_users_on_slug", unique: true
    t.index ["unconfirmed_email"], name: "index_users_on_unconfirmed_email"
    t.index ["username"], name: "index_users_on_username", unique: true
    t.index ["verification_token"], name: "index_users_on_verification_token", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "post_id", null: false
    t.datetime "updated_at", null: false
    t.boolean "upvoted", null: false
    t.bigint "user_id", null: false
    t.index ["post_id"], name: "index_votes_on_post_id"
    t.index ["user_id", "post_id"], name: "index_votes_on_user_id_and_post_id", unique: true
    t.index ["user_id"], name: "index_votes_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "announcements", "users", column: "author_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "comment_votes", "comments"
  add_foreign_key "comment_votes", "users"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "flags", "posts"
  add_foreign_key "flags", "users"
  add_foreign_key "moderation_logs", "users", column: "moderator_id"
  add_foreign_key "posts", "categories"
  add_foreign_key "posts", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "votes", "posts"
  add_foreign_key "votes", "users"
end
