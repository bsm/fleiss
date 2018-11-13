ENV['RACK_ENV'] ||= 'test'

require 'rspec'
require 'fleiss'
require 'fleiss/backend/active_record/migration'
require 'active_job'
require 'active_job/queue_adapters/fleiss_adapter'
require 'tempfile'

ActiveJob::Base.queue_adapter = :fleiss
ActiveJob::Base.logger = Logger.new(nil)

Time.zone_default = Time.find_zone!('UTC')

ActiveRecord::Base.configurations['test'] = {
  'adapter'  => 'sqlite3',
  'database' => Tempfile.new(['fleiss-test', '.sqlite3']).path,
  'pool'     => 20,
}
ActiveRecord::Base.establish_connection :test
ActiveRecord::Migration.suppress_messages do
  Fleiss::Backend::ActiveRecord::Migration.migrate(:up)
end

class TestJob < ActiveJob::Base
  queue_as 'test-queue'

  def self.performed
    @performed ||= []
  end

  def ttl
    72.hours
  end

  def perform(msg=nil)
    raise 'Failing' if msg == 'raise'

    self.class.performed.push(msg)
  end
end

RSpec.configure do |c|
  c.after :each do
    TestJob.performed.clear
    Fleiss.backend.delete_all
  end
end
