require 'fleiss'
require 'concurrent/executor/fixed_thread_pool'
require 'concurrent/atomic/atomic_fixnum'
require 'logger'
require 'securerandom'

class Fleiss::Worker
  attr_reader :queues, :uuid, :wait_time, :logger

  # Shortcut for new(*args).run
  def self.run(*args)
    new(*args).run
  end

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
      sleep @wait_time
    end
  rescue SignalException => e
    logger.info "Worker #{uuid} received #{e.message}. Shutting down..."
  ensure
    @pool.shutdown
    @pool.wait_for_termination
  end

  private

  def run_cycle
    return if @pool.shuttingdown?

    capacity = @pool.max_length - @pool.scheduled_task_count + @pool.completed_task_count
    return unless capacity.positive?

    batch = Fleiss.backend
                  .in_queue(queues)
                  .pending
                  .limit(capacity)
                  .to_a

    batch.each do |job|
      @pool.post { perform(job) }
    end
  rescue StandardError => e
    handle_exception e, 'running cycle'
  end

  def perform(job)
    thread_id = Thread.current.object_id.to_s(16).reverse
    owner     = "#{uuid}/#{thread_id}"
    return unless job.start(owner)

    logger.info { "Worker #{uuid} execute job ##{job.id} (by thread #{thread_id})" }
    finished = false
    begin
      ActiveJob::Base.execute job.job_data
      finished = true
    rescue StandardError
      finished = true
      raise
    ensure
      finished ? job.finish(owner) : job.reschedule(owner)
    end
  rescue StandardError => e
    handle_exception e, "processing job ##{job.id} (by thread #{thread_id})"
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
