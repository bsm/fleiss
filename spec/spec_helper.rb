require 'rspec'
require 'fleiss'
require 'active_job'
require 'active_job/queue_adapters/fleiss_adapter'

ActiveJob::Base.queue_adapter = :fleiss
ActiveJob::Base.logger = Logger.new(nil)

class TestJob < ActiveJob::Base
  queue_as 'test-queue'

  def self.performed
    @performed ||= []
  end

  def perform(*args)
    self.class.performed.push(args)
  end
end

RSpec.configure do |c|
  c.before :suite do
    # Fleiss.logger = Logger.new(nil)
  end

  c.after :each do
    TestJob.performed.clear
    Fleiss::PersistedJob.delete_all
  end
end
