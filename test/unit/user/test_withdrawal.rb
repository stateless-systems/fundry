require_relative '../../helper'

# TODO: Messy. Break into tests per state.
describe 'User::Payment new withdrawal' do
  before do
    @user    = new_user
    deposit  = @user.deposit BigMoney.new('10', :usd)
    deposit.complete!

    @payment = @user.withdraw BigMoney.new('10', :usd)
  end

  it 'must create payment object' do
    assert_kind_of Fundry::Payment, @payment
  end

  it 'must create payment object with new state' do
    assert_equal 'new', @payment.state
    assert_equal @payment.payment_states.first.status, @payment.state
  end

  it 'must have transfer for new state' do
    assert_kind_of Fundry::Transfer, @payment.transfer
  end

  it 'must update account balance' do
    assert_equal BigMoney.new('0', :usd), @user.balance
  end
end

describe 'User::Payment complete withdrawal' do
  before do
    @user    = new_user
    deposit  = @user.deposit BigMoney.new('10', :usd)
    deposit.complete!

    @payment = @user.withdraw BigMoney.new('10', :usd)
  end

  it 'must update state when payment is complete' do
    @payment.complete!
    assert_equal 'complete', @payment.state
    assert_equal @payment.payment_states.first(order: [:created_at.desc, :id.desc]).status, @payment.state
  end
end

describe 'User::Payment rejected withdrawal' do
  before do
    @user    = new_user
    deposit  = @user.deposit BigMoney.new('10', :usd)
    deposit.complete!

    @payment = @user.withdraw BigMoney.new('10', :usd)
  end

  it 'must refund amount when payment is rejected' do
    @payment.reject!
    assert_equal 'rejected', @payment.state
    assert_equal BigMoney.new('10', :usd), @user.balance
  end
end
