module Fundry
  class TransferError < StandardError; end
  class BalanceError  < TransferError; end

  class Transfer
    include DataMapper::Resource
    property   :id,        Serial
    property   :user_id,   Integer, required: true
    property   :parent_id, Integer
    money      :balance,            required: true, precision: 15, scale: 5
    timestamps :at

    property   :deleted_at, ParanoidDateTime

    is :tree
    belongs_to :user
    has n, :pledges, model: 'Fundry::Pledge', constraint: :destroy!
  end # Transfer
end # Fundry

