require 'spec_helper'

RSpec.describe Fleiss::Backend::ActiveRecord do
  def retrieve(job)
    described_class.find(job.provider_job_id)
  end

  it 'persists jobs' do
    job = TestJob.perform_later
    rec = retrieve(job)

    expect(rec.attributes).to include(
      'queue_name'  => 'test-queue',
      'owner'       => nil,
      'started_at'  => nil,
      'finished_at' => nil,
    )
    expect(rec.scheduled_at).to be_within(2.seconds).of(Time.zone.now)
    expect(rec.expires_at).to be_within(2.seconds).of(3.days.from_now)
    expect(rec.job_data).to include(
      'job_class'       => 'TestJob',
      'arguments'       => [],
      'executions'      => 0,
      'locale'          => 'en',
      'priority'        => nil,
      'provider_job_id' => nil,
      'queue_name'      => 'test-queue',
    )
  end

  it 'enqueues with delay' do
    job = TestJob.set(wait: 1.day).perform_later
    rec = retrieve(job)
    expect(rec.scheduled_at).to be_within(2.seconds).of(1.day.from_now)
  end

  it 'enqueues with priority' do
    job = TestJob.set(priority: 8).perform_later
    rec = retrieve(job)
    expect(rec.priority).to eq(8)
  end

  it 'exposes active job ID' do
    job = TestJob.perform_later
    rec = retrieve(job)
    expect(rec.job_id.size).to eq(36)
  end

  it 'scopes pending' do
    j1 = TestJob.perform_later
    expect(retrieve(j1).start('owner')).to be_truthy
    expect(retrieve(j1).finish('owner')).to be_truthy

    j2 = TestJob.perform_later
    _j3 = TestJob.set(wait: 1.hour).perform_later
    j4 = TestJob.set(priority: 2).perform_later

    expect(described_class.pending.ids).to eq [j4.provider_job_id, j2.provider_job_id]
  end

  it 'scopes in_progress' do
    _j1 = TestJob.perform_later
    j2 = TestJob.perform_later
    expect(retrieve(j2).start('owner')).to be_truthy

    j3 = TestJob.perform_later
    expect(retrieve(j3).start('owner')).to be_truthy
    expect(described_class.in_progress('owner').ids).to match_array [j2.provider_job_id, j3.provider_job_id]
    expect(described_class.in_progress('other').ids).to be_empty

    expect(retrieve(j3).finish('owner')).to be_truthy
    expect(described_class.in_progress('owner').ids).to eq [j2.provider_job_id]
  end

  it 'scopes by queue' do
    j1 = TestJob.perform_later
    j2 = TestJob.set(queue: 'other').perform_later
    expect(described_class.in_queue('test-queue').ids).to eq [j1.provider_job_id]
    expect(described_class.in_queue('other').ids).to eq [j2.provider_job_id]
  end

  it 'starts' do
    job = TestJob.perform_later
    rec = retrieve(job)
    expect(rec.start('owner')).to be_truthy
    expect(rec.start('other')).to be_falsey
    expect(rec.reload.owner).to eq('owner')
    expect(rec.started_at).to be_within(2.seconds).of(Time.zone.now)
  end

  it 'locks atomically' do
    24.times do
      TestJob.perform_later
    end
    counts = (1..4).map do |n|
      Thread.new do
        described_class.pending.to_a.count {|j| j.start "owner-#{n}" }
      end
    end.map(&:value)
    expect(counts.sum).to eq(24)
  end

  it 'finishes' do
    job = TestJob.perform_later
    rec = retrieve(job)
    expect(rec.finish('owner')).to be_falsey
    expect(rec.start('owner')).to be_truthy
    expect(rec.finish('other')).to be_falsey
    expect(rec.finish('owner')).to be_truthy
    expect(rec.reload.owner).to eq('owner')
    expect(rec.started_at).to be_within(2.seconds).of(Time.zone.now)
    expect(rec.finished_at).to be_within(2.seconds).of(Time.zone.now)
  end

  it 'reschedules' do
    job = TestJob.perform_later
    rec = retrieve(job)
    expect(rec.reschedule('owner')).to be_falsey
    expect(rec.start('owner')).to be_truthy
    expect(rec.reschedule('other')).to be_falsey
    expect(rec.reschedule('owner')).to be_truthy
    expect(rec.reload.owner).to be_nil
    expect(rec.started_at).to be_nil
    expect(rec.scheduled_at).to be_within(2.seconds).of(Time.zone.now)
  end

  it 'reconnects' do
    expect(ActiveRecord::Base).to receive(:clear_all_connections!).once.and_return(nil)

    expect do
      described_class.wrap_perform { raise ActiveRecord::StatementInvalid }
    end
      .to raise_error(ActiveRecord::StatementInvalid) # re-raised anyway
  end
end
