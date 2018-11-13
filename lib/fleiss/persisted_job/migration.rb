class AddFleissJobs < ActiveRecord::Migration[5.0]
  create_table :fleiss_jobs do |t|
    t.string :queue_name, limit: 50, null: false
    t.int :priority, limit: 2, null: false, default: 10
    t.int :executions, limit: 4, null: false, default: 0
    t.text :payload, null: false
    t.timestamp :scheduled_at, null: false
    t.timestamp :started_at
    t.timestamp :finished_at
    t.timestamp :expires_at
    t.string :owner, limit: 100

    t.index :queue_name
    t.index :priority
    t.index :executions
    t.index :scheduled_at
    t.index :finished_at
    t.index :expires_at
  end
end
