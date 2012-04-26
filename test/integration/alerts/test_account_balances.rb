require_relative '../helper'

describe "Balance Accounting" do
  before do
    require 'fundry/cli/check'

    developer = new_user
    @donor1   = new_user balance: BigMoney.new(100, :usd)
    @donor2   = new_user balance: BigMoney.new(100, :usd)

    project   = new_project user: developer,  name: 'Test project', web: 'http://www.example.com'
    feature   = Fundry::Feature.create project: project, name: 'Test feature', detail: 'blah'

    @donor1.pledge feature, BigMoney.new(15.13, :usd)
    @donor2.pledge feature, BigMoney.new(55.75, :usd)
    mailbox.clear
  end

  after do
    Peon.flush
  end

  it "should not email alerts when balance accounting is fine" do
    Fundry::Cli::Check.new(Fundry::User.repository.adapter).balances
    assert_equal 0, mailbox.length, "mailbox is empty"
  end

  it "should find dodgy transfers and email alerts" do
    @donor1.update(balance: BigMoney.new(0, :usd))

    expect = "ID: %-8d BALANCE: 0.00 TRANSFERS: 84.87 USER:" % @donor1.id

    Fundry::Cli::Check.new(Fundry::User.repository.adapter).balances
    assert_equal 1, mailbox.length, "mailbox contains an alert"
    assert_match expect, mailbox.join(''), "mailbox contains dodgy info"
  end
end
