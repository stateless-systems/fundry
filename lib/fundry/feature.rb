require 'fundry/feature/approval'
require 'fundry/feature/payments'
require 'fundry/slug'

module Fundry
  class Feature
    attr_accessor :previous_state
    include DataMapper::Resource
    include Fundry::Slug

    property   :id,         Serial
    # user that pledged first or project owner.
    property   :user_id,    Integer
    property   :project_id, Integer, required: true
    property   :name,       String,  required: true, length: 64
    property   :detail,     Text,    lazy: false, required: true
    property   :url,        Text,    lazy: false
    property   :state,      String,  default: 'new', index: true
    property   :deleted_at, ParanoidDateTime
    money      :balance,    required: true, precision: 15, scale: 5, default: BigMoney.new(0, :usd)
    timestamps :at

    has n, :events
    has n, :pledges
    has n, :comments
    has n, :feature_states
    has n, :acceptances,    model: 'Fundry::FeatureAcceptance'

    belongs_to :project
    belongs_to :user

    after :create do
      feature_states.create(status: 'new')
    end

    before :update do
      property = properties[:state]
      self.previous_state = dirty_attributes.key?(property) ? original_attributes[property] : self.state
    end

    after :update do
      initiate_approval! if previous_state != 'complete' && state == 'complete'
      initiate_refunds!  if previous_state != 'rejected' && state == 'rejected'
    end

    def self.top
      all(state: %w(new pending), order: [:balance_amount.desc])
    end

    def self.pending
      all(state: %w(new pending))
    end

    def self.complete
      all(state: 'complete')
    end

    def created_by
      @created_by ||= user || pledges(order: :created_at.asc, limit: 1).transfer.user.first || project.user
    end

    def pledges_by_user_id user_id
      # The pg planner in 8.4.1 optimizes out trivial subqueries into joins. Take that mysql.
      Pledge.all(transfer: { user_id: user_id }, feature_id: id)
    end
  end # Feature
end # Fundry
