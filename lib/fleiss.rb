require 'active_job'
require 'active_job/queue_adapters/fleiss_adapter'
require 'fleiss/backend'

module Fleiss
  DEFAULT_QUEUE = 'default'.freeze

  def self.backend
    self::Backend::ActiveRecord
  end
end
