require 'fleiss'
require 'fleiss/executor'
require 'securerandom'

class Fleiss::Worker
  attr_reader :queues, :uuid, :wait_time

  # Shortcut for new(**opts).run
  def self.run(**opts)
    new(**opts).run
  end

  # Init a new worker instance
  # @option [Array<String>] :queues queues to watch. Default: ["default"]
  # @option [Integer] :concurrency the number of concurrent pool. Default: 10
  # @option [Numeric] :wait_time maximum time (in seconds) to wait for jobs when retrieving next batch. Default: 1s.
  def initialize(queues: [Fleiss::DEFAULT_QUEUE], concurrency: 10, wait_time: 1)
    @uuid      = SecureRandom.uuid
    @queues    = Array(queues)
    @pool      = Fleiss::Executor.new(max_size: concurrency)
    @wait_time = wait_time
  end

  # Run starts the worker
  def run
    log(:info) { "Worker #{uuid} starting - queues: #{queues.inspect}, concurrency: #{@pool.max_size}" }
    loop do
      run_cycle
      sleep @wait_time
    end
  rescue SignalException => e
    log(:info) { "Worker #{uuid} received #{e.message}. Shutting down..." }
  ensure
    @pool.shutdown
    @pool.wait_for_termination
  end

  private

  def log(severity, &block)
    logger = ActiveJob::Base.logger
    if logger.respond_to?(:tagged)
      logger.tagged('Fleiss') { logger.send(severity, &block) }
    else
      logger.send(severity, &block)
    end
  end

  def run_cycle
    return unless @pool.running?

    limit = @pool.capacity
    return unless limit.positive?

    batch = Fleiss.backend
                  .in_queue(queues)
                  .pending
                  .limit(limit)
                  .to_a

    batch.each do |job|
      @pool.post do
        thread_id = Thread.current.object_id.to_s(16).reverse
        Fleiss.backend.wrap_perform { perform(job, thread_id) }
      rescue StandardError => e
        log_exception e, "processing job ##{job.id} (by thread #{thread_id})"
      end
    end
  rescue StandardError => e
    log_exception e, 'running cycle'
  end

  def perform(job, thread_id)
    owner = "#{uuid}/#{thread_id}"
    return unless job.start(owner)

    ActiveSupport::Notifications.instrument('fleiss.worker.perform', id: job.id, uuid: uuid, thread_id: thread_id) do |payload|
      log(:info) { "Worker #{uuid} execute job ##{job.id} (by thread #{thread_id})" }
      finished = false
      begin
        ActiveJob::Base.execute job.job_data
        finished = true
      rescue StandardError => e
        payload[:error] = e
        finished = true
        raise
      ensure
        finished ? job.finish(owner) : job.reschedule(owner)
      end
    end
  end

  def log_exception(err, intro)
    log(:error) do
      [
        "Worker #{uuid} error on #{intro}:",
        "#{err.class.name}: #{err.message}",
        err.backtrace,
      ].compact.flatten.join("\n")
    end
  end
end
