module Fundry
  class PaymentStateError < StandardError; end
  class PaymentState
    include DataMapper::Resource
    property   :id,         Serial
    property   :payment_id, Integer, required: true
    property   :status,     String
    property   :detail,     Text
    timestamps :created_at

    belongs_to :payment

    STATES = %w{new rejected started canceled pending complete}.to_set.freeze

    after :create do
      payment.update(state: status) unless payment.state == status
    end
  end # PaymentState
end # Fundry
