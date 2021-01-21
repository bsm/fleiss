require 'spec_helper'
require 'fleiss/executor'

RSpec.describe Fleiss::Executor do
  subject { described_class.new max_size: 2 }

  after   { subject.kill }

  it 'checks capacity' do
    expect(described_class.new.capacity).to eq(1)

    expect(subject.capacity).to eq(2)
    subject.post { sleep(1) }
    expect(subject.capacity).to eq(1)
    subject.post { sleep(1) }
    expect(subject.capacity).to eq(0)
  end

  it 'discards execution when capacity is reached' do
    n = Concurrent::AtomicFixnum.new(0)
    10.times do
      10.times { subject.post { n.increment } }
      sleep(0.001)
    end
    subject.shutdown
    subject.wait_for_termination(1)
    expect(n.value).to be_within(10).of(20)
  end
end
