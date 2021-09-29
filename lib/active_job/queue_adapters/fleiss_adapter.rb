require 'fleiss'

module ActiveJob
  module QueueAdapters
    class FleissAdapter
      def enqueue(job) # :nodoc:
        enqueue_at(job, nil)
      end

      def enqueue_at(job, scheduled_at) # :nodoc:
        job_id = Fleiss.backend.enqueue(job, scheduled_at: scheduled_at)
        job.provider_job_id = job_id
        job_id
      end
    end
  end
end
