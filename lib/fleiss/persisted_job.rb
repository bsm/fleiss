require 'active_record'

module Fleiss
  class PersistedJob < ActiveRecord::Base
    self.table_name = 'fleiss_jobs'

    require 'fleiss/persisted_job/query_scopes'
    include QueryScopes
  end
end
