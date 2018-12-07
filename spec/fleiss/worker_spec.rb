require 'spec_helper'
require 'fleiss/worker'

RSpec.describe Fleiss::Worker do
  subject do
    described_class.new queues: TestJob.queue_name, wait_time: 0.01
  end

  let! :runner do
    t = Thread.new { subject.run }
    t.abort_on_exception = true
    t
  end

  after do
    runner.kill
  end

  def wait_for
    100.times do
      break if yield

      sleep(0.1)
    end
    expect(yield).to be_truthy
  end

  it 'should run' do
    # seed 24 jobs
    24.times {|n| TestJob.perform_later(n) }
    wait_for { Fleiss.backend.not_finished.count.positive? }

    # ensure runner processes them all
    wait_for { Fleiss.backend.not_finished.count.zero? }

    # check what's been performed
    expect(TestJob.performed.size).to eq(24)
    expect(Fleiss.backend.finished.count).to eq(24)
    expect(TestJob.performed).to match_array(0..23)
  end

  it 'should handle failing jobs' do
    TestJob.perform_later('raise')
    wait_for { Fleiss.backend.not_finished.count.zero? }
    expect(Fleiss.backend.finished.count).to eq(1)
  end
end