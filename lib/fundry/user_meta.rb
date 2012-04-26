require 'fundry/user'

module Fundry
  # Cached user meta data.
  class UserMeta
    include DataMapper::Resource
    property :user_id,                 Integer, key: true
    property :donation,                Integer, default: 0
    property :pledge,                  Integer, default: 0
    property :pledge_approval,         Integer, default: 0
    property :pledge_complete,         Integer, default: 0
    property :pledge_objection,        Integer, default: 0
    property :pledge_pending,          Integer, default: 0
    money    :donation_balance,        precision: 15, scale: 5, default: BigMoney.new(0, :usd)
    money    :pledge_pending_balance,  precision: 15, scale: 5, default: BigMoney.new(0, :usd)
    money    :pledge_complete_balance, precision: 15, scale: 5, default: BigMoney.new(0, :usd)
    money    :withdrawn_balance,       precision: 15, scale: 5, default: BigMoney.new(0, :usd)

    belongs_to :user
  end
end
