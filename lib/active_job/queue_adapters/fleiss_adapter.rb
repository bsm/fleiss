module ActiveJob
  module QueueAdapters
    class FleissAdapter
      def enqueue(job) #:nodoc:
        enqueue_at(job, nil)
      end

      def enqueue_at(job, scheduled_at) #:nodoc:
        expires_at = job.timeout.seconds.from_now if job.respond_to?(:timeout)
        scheduled_at = Time.zone.at(scheduled_at) if scheduled_at

        job_id = Fleiss::PersistedJob.create!(
          payload: job.serialize,
          queue_name: job.queue_name,
          priority: job.priority,
          scheduled_at: scheduled_at,
          expires_at: expires_at,
        ).id
        job.provider_job_id = job_id
        job_id
      end
    end
  end
end
