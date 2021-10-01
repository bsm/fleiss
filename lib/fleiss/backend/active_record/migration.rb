require 'fleiss/backend/active_record'

module Fleiss
  module Backend
    class ActiveRecord
      class Migration < ::ActiveRecord::Migration[6.0]
        def change
          table_name = :fleiss_jobs

          create_table(table_name) do |t|
            t.string :queue_name, limit: 50, null: false
            t.integer :priority, limit: 2, null: false, default: 10
            t.text :payload, null: false
            t.timestamp :scheduled_at, null: false
            t.timestamp :started_at
            t.timestamp :finished_at
            t.timestamp :expires_at
            t.string :owner, limit: 100
            t.timestamp :lock_expires_at

            t.index :queue_name
            t.index :priority
            t.index :scheduled_at
            t.index :finished_at
            t.index :expires_at
            t.index :owner
          end unless table_exists?(table_name)

          add_column(table_name, :lock_expires_at, :timestamp) \
            unless column_exists?(table_name, :lock_expires_at)
        end
      end
    end
  end
end
