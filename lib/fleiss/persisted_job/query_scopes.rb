module Fleiss
  class PersistedJob
    module QueryScopes
      extend ActiveSupport::Concern

      included do
        scope :not_finished, -> { where(finished_at: nil) }
        scope :not_expired,  -> { where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].lt(Time.zone.now))) }
      end

      class_methods do
        # @return [ActiveRecord::Relation] pending scope
        def pending
          now = Time.zone.now
          not_finished.not_expired
                      .where(arel_table[:scheduled_at].lteq(now))
                      .where(arel_table[:started_at].eq(nil).or(arel_table[:started_at].lt(arel_table[:scheduled_at])))
        end
      end
    end
  end
end
