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

  create_table "automation_runs", force: true do |t|
    t.string   "uuid",                     null: false
    t.string   "user_id",                  null: false
    t.string   "machine_id",               null: false
    t.string   "automation_id"
    t.text     "run_attributes"
    t.integer  "start_time",     limit: 8
    t.integer  "end_time",       limit: 8
    t.boolean  "success"
    t.text     "error_details"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "automations", force: true do |t|
    t.string   "uuid",                                 null: false
    t.string   "user_id",                              null: false
    t.string   "name",             default: "",        null: false
    t.string   "language",         default: "chef",    null: false
    t.string   "visibility",       default: "Private", null: false
    t.string   "cookbook"
    t.string   "cookbook_version"
    t.string   "recipes"
    t.text     "script"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "automations", ["uuid"], name: "index_automations_on_uuid", unique: true, using: :btree

  create_table "key_value_pairs", force: true do |t|
    t.string   "key",               null: false
    t.string   "type"
    t.integer  "automation_id"
    t.integer  "task_id"
    t.integer  "automation_run_id"
    t.integer  "test_case_id"
    t.text     "value"
    t.text     "data_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "state_changes", force: true do |t|
    t.string   "task_execution_id"
    t.string   "property"
    t.string   "action"
    t.text     "value"
    t.text     "old_value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "task_executions", force: true do |t|
    t.string   "uuid",                        null: false
    t.string   "task_id"
    t.integer  "automation_run_id"
    t.integer  "index_in_run"
    t.integer  "start_time",        limit: 8
    t.integer  "end_time",          limit: 8
    t.text     "state_before"
    t.text     "state_after"
    t.boolean  "success"
    t.text     "error_details"
    t.text     "output"
    t.text     "sourcecode"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tasks", force: true do |t|
    t.string   "uuid",          null: false
    t.string   "automation_id", null: false
    t.string   "resource"
    t.string   "action"
    t.text     "sourcecode"
    t.text     "sourcehash"
    t.text     "sourcefile"
    t.string   "sourceline"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "test_cases", force: true do |t|
    t.string   "uuid",                        null: false
    t.string   "test_suite_id"
    t.string   "automation_run_id"
    t.text     "skip_task_uuids",             null: false
    t.text     "repeat_task_uuids",           null: false
    t.integer  "start_time",        limit: 8
    t.integer  "end_time",          limit: 8
    t.string   "executing_host"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "test_coverage_goals", force: true do |t|
    t.text     "idempotence"
    t.text     "combinations"
    t.string   "repeat_N"
    t.string   "graph"
    t.boolean  "only_connect_to_start"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "test_suites", force: true do |t|
    t.string   "uuid",                  null: false
    t.string   "user_id",               null: false
    t.string   "automation_id",         null: false
    t.string   "lxc_prototype",         null: false
    t.text     "test_coverage_goal_id", null: false
    t.string   "name"
    t.text     "parameter_test_values"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: true do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

end
