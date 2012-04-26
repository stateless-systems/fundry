require 'digest/sha1'

module Fundry
  class FeatureAcceptance
    include DataMapper::Resource
    property :id,          Serial
    property :token,       String,  length: 40, writer: :private, index: true
    property :feature_id,  Integer
    property :pledge_id,   Integer
    property :transfer_id, Integer
    property :open,        Boolean, required: true, default: true
    property :state,       String,  required: true, default: 'pending', index: true
    property :comment,     Text
    timestamps :at

    belongs_to :pledge
    belongs_to :feature
    belongs_to :transfer

    before :create do
      attribute_set(:token, Digest::SHA1.hexdigest("#{Time.now.to_f}#{rand}"))
    end

    after :create do
      schedule_work :donor_email
    end

    def worker_path
      '/job/feature/acceptance'
    end

    STATES = %w{accepted rejected pending}.freeze
  end # FeatureAcceptance
end # Fundry
