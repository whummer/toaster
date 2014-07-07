class CreateAllTables < ActiveRecord::Migration

  def change
    try_create(method(:create_automations), :automations)
    try_create(method(:create_automation_runs), :automation_runs)
    try_create(method(:create_key_value_pairs), :key_value_pairs)
    try_create(method(:create_tasks), :tasks)
    try_create(method(:create_task_executions), :task_executions)
    try_create(method(:create_state_changes), :state_changes)
    try_create(method(:create_test_suites), :test_suites)
    try_create(method(:create_test_cases), :test_cases)
    try_create(method(:create_test_coverage_goals), :test_coverage_goals)
  end

  def create_automations 
    create_table(:automations) do |t|
      t.string :uuid,           :null => false
      t.string :user_id,        :null => false
      t.string :name,           :null => false, :default => ""
      t.string :language,       :null => false, :default => "chef"
      t.string :visibility,     :null => false, :default =>  "Private"
      t.string :cookbook
      t.string :cookbook_version
      t.string :recipes
      t.text :script

      t.timestamps
    end
    add_index :automations, :uuid, :unique => true
  end

  def create_automation_runs 
    create_table(:automation_runs) do |t|
      t.string :uuid,           :null => false
      t.string :user_id,        :null => false
      t.string :machine_id,     :null => false
      t.string :automation_id
      t.text :run_attributes
      t.integer :start_time, :limit => 8 
      t.integer :end_time, :limit => 8 
      t.boolean :success
      t.text :error_details

      t.timestamps
    end
  end

  def create_tasks 
    create_table(:tasks) do |t|
      t.string :uuid,           :null => false
      t.string :automation_id,  :null => false
      t.string :resource
      t.string :action
      #t.string :parameters
      t.text :sourcecode
      t.text :sourcehash
      t.text :sourcefile
      t.string :sourceline

      t.timestamps
    end
  end

  def create_task_executions
    create_table(:task_executions) do |t|
      t.string :uuid,           :null => false
      t.string :task_id
      t.integer :automation_run_id
      t.integer :index_in_run
      t.integer :start_time,    :limit => 8 
      t.integer :end_time,      :limit => 8 
      t.text :state_before
      t.text :state_after 
      t.boolean :success
      t.text :error_details
      t.text :output
      t.text :sourcecode

      t.timestamps
    end
  end

  def create_key_value_pairs 
    create_table(:key_value_pairs) do |t|
      t.string :key,              :null => false
      t.string :type
      t.integer :automation_id
      t.integer :task_id
      t.integer :automation_run_id
      t.integer :test_case_id
      t.text :value
      t.text :data_type

      t.timestamps
    end
  end

  def create_state_changes
    create_table(:state_changes) do |t|
      t.string :task_execution_id
      t.string :property
      t.string :action
      t.text :value
      t.text :old_value

      t.timestamps
    end
  end

  def create_test_suites
    create_table(:test_suites) do |t|
      t.string :uuid,                :null => false
      t.string :user_id,             :null => false
      t.string :automation_id,       :null => false
      t.string :lxc_prototype,       :null => false
      t.text :test_coverage_goal_id, :null => false
      t.string :name
      t.text :parameter_test_values

      t.timestamps
    end
  end

  def create_test_cases
    create_table(:test_cases) do |t|
      t.string :uuid,            :null => false
      t.string :test_suite_id
      t.string :automation_run_id
      t.text :skip_task_uuids,   :null => false
      t.text :repeat_task_uuids, :null => false
      t.integer :start_time,     :limit => 8
      t.integer :end_time,       :limit => 8
      t.string :executing_host

      t.timestamps
    end
  end

  def create_test_coverage_goals
    create_table(:test_coverage_goals) do |t|
      t.text :idempotence
      t.text :combinations
      t.string :repeat_N
      t.string :graph
      t.boolean :only_connect_to_start

      t.timestamps
    end
  end

  def try_create(method, table_name)
    begin
      method.call()
    rescue
      drop_table table_name
      method.call()
    end
  end
end
