module Fleiss
  module Backend
    class ActiveRecord
      module Concern
        extend ActiveSupport::Concern

        included do
          scope :in_queue, ->(qs) { where(queue_name: Array.wrap(qs)) }
          scope :finished, -> { where.not(finished_at: nil) }
          scope :not_finished, -> { where(finished_at: nil) }
          scope :not_expired,  lambda {|now = Time.zone.now|
                                 where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(now)))
                               }
          scope :started,      -> { where(arel_table[:started_at].not_eq(nil)) }
          scope :not_started,  -> { where(arel_table[:started_at].eq(nil)) }
          scope :scheduled,    ->(now = Time.zone.now) { where(arel_table[:scheduled_at].gt(now)) }
        end

        module ClassMethods
          def wrap_perform(&block)
            connection_pool.with_connection(&block)
          rescue ::ActiveRecord::StatementInvalid
            ::ActiveRecord::Base.clear_active_connections!
            raise
          end

          # @return [ActiveRecord::Relation] pending scope
          def pending(now = Time.zone.now)
            not_finished
              .not_expired(now)
              .not_started
              .where(arel_table[:scheduled_at].lteq(now))
              .order(priority: :desc)
              .order(scheduled_at: :asc)
          end

          # @return [ActiveRecord::Relation] in-progress scope
          def in_progress(owner)
            started.not_finished.where(owner: owner)
          end

          # @param [ActiveJob::Base] job the job instance
          # @option [Time] :scheduled_at schedule job at
          def enqueue(job, scheduled_at: nil)
            scheduled_at = scheduled_at ? Time.zone.at(scheduled_at) : Time.zone.now
            expires_at = scheduled_at + job.ttl.seconds if job.respond_to?(:ttl)

            create!(
              payload: JSON.dump(job.serialize),
              queue_name: job.queue_name,
              priority: job.priority.to_i,
              scheduled_at: scheduled_at,
              expires_at: expires_at,
            ).id
          end
        end

        # @return [Hash] serialized job data
        def job_data
          @job_data ||= JSON.parse(payload)
        end

        # @return [String] the ActiveJob ID
        def job_id
          job_data['job_id']
        end

        # Acquires a lock and starts the job.
        # @param [String] owner
        # @return [Boolean] true if job was started.
        def start(owner, now: Time.zone.now)
          with_isolation do
            self.class.pending(now)
                .where(id: id)
                .update_all(started_at: now, owner: owner)
          end == 1
        rescue ::ActiveRecord::SerializationFailure
          false
        end

        # Marks a job as finished.
        # @param [String] owner
        # @return [Boolean] true if successful.
        def finish(owner, now: Time.zone.now)
          with_isolation do
            self.class
                .in_progress(owner)
                .where(id: id)
                .update_all(finished_at: now)
          end == 1
        rescue ::ActiveRecord::SerializationFailure
          false
        end

        # Reschedules the job to run again.
        def reschedule(owner, now: Time.zone.now)
          with_isolation do
            self.class
                .in_progress(owner)
                .where(id: id)
                .update_all(started_at: nil, owner: nil, scheduled_at: now)
          end == 1
        rescue ::ActiveRecord::SerializationFailure
          false
        end

        private

        def with_isolation(&block)
          conn = self.class.connection
          if conn.supports_transaction_isolation? && conn.adapter_name != 'SQLite'
            self.class.transaction(isolation: :repeatable_read, &block)
          else
            yield
          end
        end
      end
    end
  end
end
