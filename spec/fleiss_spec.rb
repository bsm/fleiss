require 'spec_helper'

RSpec.describe Fleiss do
  it 'has a backend' do
    expect(described_class.backend).to eq(Fleiss::Backend::ActiveRecord)
  end

  it 'enqueues' do
    expect do
      TestJob.set(wait: 1.week).perform_later
    end.to change { described_class.backend.count }.by(1)
  end
end
