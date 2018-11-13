require 'active_record'

module Fleiss
  module Backend
    class ActiveRecord < ::ActiveRecord::Base
      self.table_name = 'fleiss_jobs'

      require 'fleiss/backend/active_record/concern'
      include self::Concern
    end
  end
end
