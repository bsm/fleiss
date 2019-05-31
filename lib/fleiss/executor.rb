require 'fleiss'
require 'concurrent/executor/simple_executor_service'

class Fleiss::Executor < Concurrent::SimpleExecutorService
  attr_reader :max_size

  def post(&block)
    super unless capacity.zero?
  end

  def capacity
    val = @max_size - @count.value
    val.positive? ? val : 0
  end

  private

  def ns_initialize(opts={})
    super()
    @max_size = opts.fetch(:max_size, 1).to_i
  end
end
