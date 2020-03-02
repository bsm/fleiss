ENV['RACK_ENV'] ||= 'test'

require 'rspec'
require 'fleiss'
require 'fleiss/backend/active_record/migration'
require 'active_job'
require 'active_job/queue_adapters/fleiss_adapter'
require 'fileutils'

ActiveJob::Base.queue_adapter = :fleiss
ActiveJob::Base.logger = Logger.new(nil)

Time.zone_default = Time.find_zone!('UTC')

tmpdir = File.expand_path('./tmp', __dir__)
FileUtils.rm_rf tmpdir
FileUtils.mkdir_p tmpdir

database_url = ENV['DATABASE_URL'] || "sqlite3://#{tmpdir}/fleiss-test.sqlite3"
ActiveRecord::Base.configurations = { 'test' => { 'url' => database_url, 'pool' => 20 } }

ActiveRecord::Base.establish_connection :test
ActiveRecord::Base.connection.drop_table('fleiss_jobs', if_exists: true)
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

  def perform(msg = nil)
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
