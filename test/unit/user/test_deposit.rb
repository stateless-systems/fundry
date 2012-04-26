require_relative '../../helper'

describe 'User::Payment new deposit' do
  before do
    @user    = new_user
    @payment = @user.deposit BigMoney.new('10', :usd)
  end

  it 'must create payment object' do
    assert_kind_of Fundry::Payment, @payment
  end

  it 'must create payment object with new state' do
    assert_equal 'new', @payment.state
    assert_equal @payment.payment_states.first.status, @payment.state
  end

  it 'must not have transfer for new state' do
    assert_equal nil, @payment.transfer
  end
end

describe 'User::Payment complete deposit' do
  before do
    @user    = new_user
    @payment = @user.deposit BigMoney.new('10', :usd)
  end

  it 'must transfer amount when payment is complete' do
    @payment.complete!
    assert_kind_of Fundry::Transfer, @payment.transfer
    assert_equal -BigMoney.new('10', :usd), @payment.transfer.balance
  end

  it 'must update state when payment is complete' do
    @payment.complete!
    assert_equal 'complete', @payment.state
    assert_equal @payment.payment_states.first(order: [:created_at.desc, :id.desc]).status, @payment.state
  end
end

describe 'User::Payment rejected deposit' do
  before do
    @user    = new_user
    @payment = @user.deposit BigMoney.new('10', :usd)
  end

  it 'must not transfer amount when payment is rejected' do
    @payment.reject!
    assert_equal 'rejected', @payment.state
    assert_equal nil, @payment.transfer
  end
end
