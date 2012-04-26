require_relative '../../helper'

describe 'User::Paypal' do
  it 'must not raise transfer error when overdrawing gateway account' do
    Fundry::User::Paypal.get.transfer(Fundry::User::Escrow.get, BigMoney.new(5, :usd))
    assert_equal 2, Fundry::Transfer.all.size
    assert_equal 1, Fundry::User::Paypal.get.transfers.size
    assert_equal 1, Fundry::User::Escrow.get.transfers.size
    assert_equal BigMoney.new(5, :usd), Fundry::User::Escrow.get.balance
  end
end

describe 'User' do
  it 'must raise transfer error when amount is less than zero' do
    assert_raises Fundry::TransferError do
      Fundry::User::Escrow.get.transfer(Fundry::User::Commissions.get, BigMoney.new(-3, :usd))
      assert_equal 0, Fundry::Transfer.all.size
    end
  end

  it 'must raise transfer error when amount is equal to zero' do
    assert_raises Fundry::TransferError do
      Fundry::User::Escrow.get.transfer(Fundry::User::Commissions.get, BigMoney.new(0, :usd))
      assert_equal 0, Fundry::Transfer.all.size
    end
  end

  it 'must update balance if transfer succeeds' do
    Fundry::User::Paypal.get.transfer(Fundry::User::Commissions.get, BigMoney.new(5, :usd))
    assert_equal 2, Fundry::Transfer.all.size
    assert_equal 1, Fundry::User::Paypal.get.transfers.size
    assert_equal 1, Fundry::User::Commissions.get.transfers.size
    assert_equal BigMoney.new(5, :usd), Fundry::User::Commissions.get.balance
  end

  it 'must roll back transfer if transfer fails' do
    begin
      Fundry::User::Escrow.get.transfer(Fundry::User::Commissions.get, BigMoney.new(7, :usd))
    rescue Fundry::TransferError
    ensure
      assert_equal 0, Fundry::Transfer.all.size
      assert_equal 0, Fundry::User::Escrow.get.transfers.size
      assert_equal 0, Fundry::User::Commissions.get.transfers.size
      assert_equal BigMoney.new(0, :usd), Fundry::User::Commissions.get.balance
    end
  end
end
