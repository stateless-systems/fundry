module Fundry
  class FeatureStateError < StandardError; end
  class FeatureState
    include DataMapper::Resource
    property   :id,         Serial
    property   :feature_id, Integer, required: true
    property   :status,     String
    property   :detail,     Text
    timestamps :created_at

    belongs_to :feature

    STATES = %w{new pending rejected complete}.to_set.freeze
    RANK   = { new: 1, pending: 2, rejected: 4, complete: 4 }

    before :create do
      if feature.feature_states.empty?
        true
      elsif RANK[status.to_sym] <= (RANK[feature.state.to_sym] || 0)
        raise Fundry::FeatureStateError, "Feature already marked as '#{feature.state}' and can't be reverted to '#{status}'."
      end
    end

    after :create do
      feature.update(state: status) unless feature.state == status
    end
  end # State
end # Feature
