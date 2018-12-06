require 'fleiss'
require 'concurrent/executor/fixed_thread_pool'
require 'concurrent/atomic/atomic_fixnum'
require 'logger'
require 'securerandom'

class Fleiss::Worker
  attr_reader :queues, :uuid, :wait_time, :logger

  # Init a new worker instance
  # @param [ConnectionPool] disque client connection pool
  # @param [Hash] options
  # @option [Array<String>] :queues queues to watch. Default: ["default"]
  # @option [Integer] :concurrency the number of concurrent pool. Default: 10
  # @option [Numeric] :wait_time maximum time (in seconds) to wait for jobs when retrieving next batch. Default: 1s.
  # @option [Logger] :logger optional logger.
  def initialize(queues: [Fleiss::DEFAULT_QUEUE], concurrency: 10, wait_time: 1, logger: nil)
    @uuid      = SecureRandom.uuid
    @queues    = Array(queues)
    @pool      = Concurrent::FixedThreadPool.new(concurrency, fallback_policy: :discard)
    @wait_time = wait_time
    @logger    = logger || Logger.new(nil)
  end

  # Run starts the worker
  def run
    logger.info "Worker #{uuid} starting - queues: #{queues.inspect}, concurrency: #{@pool.max_length}"
    loop do
      run_cycle
      break if @stopped

      sleep @wait_time
    end
    logger.info "Worker #{uuid} shutting down"
  end

  # Blocks until worker until it's stopped.
  def wait
    @pool.shutdown
    @pool.wait_for_termination(1)

    Fleiss.backend
          .in_queue(queues)
          .in_progress(uuid)
          .reschedule_all(10.seconds.from_now)
    @pool.wait_for_termination
    logger.info "Worker #{uuid} shutdown complete"
  rescue StandardError => e
    handle_exception e, 'shutdown'
  end

  # Initiates the shutdown process
  def shutdown
    @stopped = true
  end

  private

  def run_cycle
    capacity = @pool.max_length - @pool.scheduled_task_count + @pool.completed_task_count
    return unless capacity.positive?

    batch = Fleiss.backend
                  .in_queue(queues)
                  .pending
                  .limit(capacity)
                  .to_a

    batch.each do |job|
      break if @stopped

      @pool.post { perform(job) }
    end
  rescue StandardError => e
    handle_exception e, 'running cycle'
  end

  def perform(job)
    return unless job.start(uuid)

    thread_id = Thread.current.object_id.to_s(36)
    logger.info { "Worker #{uuid} execute job ##{job.id} by thread #{thread_id}" }

    ActiveJob::Base.execute job.job_data
  rescue StandardError => e
    handle_exception e, "processing job ##{job.id} (by thread #{thread_id})"
  ensure
    job.finish(uuid)
  end

  def handle_exception(err, intro)
    lines = [
      "Worker #{uuid} error on #{intro}:",
      "#{err.class.name}: #{err.message}",
      err.backtrace,
    ].compact.flatten

    logger.error lines.join("\n")
  end
end
