# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140628002058) do

  create_table "automation_runs", force: :cascade do |t|
    t.string   "uuid",           limit: 255,   null: false
    t.string   "user_id",        limit: 255,   null: false
    t.string   "machine_id",     limit: 255,   null: false
    t.string   "automation_id",  limit: 255
    t.text     "run_attributes", limit: 65535
    t.integer  "start_time",     limit: 8
    t.integer  "end_time",       limit: 8
    t.boolean  "success"
    t.text     "error_details",  limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "automations", force: :cascade do |t|
    t.string   "uuid",             limit: 255,                       null: false
    t.string   "user_id",          limit: 255,                       null: false
    t.string   "name",             limit: 255,   default: "",        null: false
    t.string   "language",         limit: 255,   default: "chef",    null: false
    t.string   "visibility",       limit: 255,   default: "Private", null: false
    t.string   "cookbook",         limit: 255
    t.string   "cookbook_version", limit: 255
    t.string   "recipes",          limit: 255
    t.text     "script",           limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "automations", ["uuid"], name: "index_automations_on_uuid", unique: true, using: :btree

  create_table "key_value_pairs", force: :cascade do |t|
    t.string   "key",               limit: 255,   null: false
    t.string   "type",              limit: 255
    t.integer  "automation_id",     limit: 4
    t.integer  "task_id",           limit: 4
    t.integer  "automation_run_id", limit: 4
    t.integer  "test_case_id",      limit: 4
    t.text     "value",             limit: 65535
    t.text     "data_type",         limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "state_changes", force: :cascade do |t|
    t.string   "task_execution_id", limit: 255
    t.string   "property",          limit: 255
    t.string   "action",            limit: 255
    t.text     "value",             limit: 65535
    t.text     "old_value",         limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "task_executions", force: :cascade do |t|
    t.string   "uuid",              limit: 255,   null: false
    t.string   "task_id",           limit: 255
    t.integer  "automation_run_id", limit: 4
    t.integer  "index_in_run",      limit: 4
    t.integer  "start_time",        limit: 8
    t.integer  "end_time",          limit: 8
    t.text     "state_before",      limit: 65535
    t.text     "state_after",       limit: 65535
    t.boolean  "success"
    t.text     "error_details",     limit: 65535
    t.text     "output",            limit: 65535
    t.text     "sourcecode",        limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tasks", force: :cascade do |t|
    t.string   "uuid",          limit: 255,   null: false
    t.string   "automation_id", limit: 255,   null: false
    t.string   "resource",      limit: 255
    t.string   "action",        limit: 255
    t.text     "sourcecode",    limit: 65535
    t.text     "sourcehash",    limit: 65535
    t.text     "sourcefile",    limit: 65535
    t.string   "sourceline",    limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "test_cases", force: :cascade do |t|
    t.string   "uuid",              limit: 255,   null: false
    t.string   "test_suite_id",     limit: 255
    t.string   "automation_run_id", limit: 255
    t.text     "skip_task_uuids",   limit: 65535, null: false
    t.text     "repeat_task_uuids", limit: 65535, null: false
    t.integer  "start_time",        limit: 8
    t.integer  "end_time",          limit: 8
    t.string   "executing_host",    limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "test_coverage_goals", force: :cascade do |t|
    t.text     "idempotence",           limit: 65535
    t.text     "combinations",          limit: 65535
    t.string   "repeat_N",              limit: 255
    t.string   "graph",                 limit: 255
    t.boolean  "only_connect_to_start"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "test_suites", force: :cascade do |t|
    t.string   "uuid",                  limit: 255,   null: false
    t.string   "user_id",               limit: 255,   null: false
    t.string   "automation_id",         limit: 255,   null: false
    t.string   "lxc_prototype",         limit: 255,   null: false
    t.text     "test_coverage_goal_id", limit: 65535, null: false
    t.string   "name",                  limit: 255
    t.text     "parameter_test_values", limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  limit: 255, default: "", null: false
    t.string   "encrypted_password",     limit: 255, default: "", null: false
    t.string   "reset_password_token",   limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          limit: 4,   default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 255
    t.string   "last_sign_in_ip",        limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

end
