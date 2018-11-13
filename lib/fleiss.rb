module Fleiss
  DEFAULT_QUEUE = 'default'.freeze

  def self.backend
    self::Backend::ActiveRecord
  end
end

require 'fleiss/backend'
