require_relative '../helper'

describe "Pledge Accounting" do
  before do
    require 'fundry/cli/check'
    require 'fundry/cli/payment'

    developer = new_user
    @donor1   = new_user balance: BigMoney.new(100, :usd)
    @donor2   = new_user balance: BigMoney.new(100, :usd)

    project   = new_project user: developer,  name: 'Test project', web: 'http://www.example.com'
    feature   = Fundry::Feature.create project: project, name: 'Test feature', detail: 'blah'

    @donor1.pledge feature, BigMoney.new(15.13, :usd)
    @donor2.pledge feature, BigMoney.new(55.75, :usd)

    feature.feature_states.create(status: 'complete')
    feature.acceptances.update(state: 'accepted')

    Fundry::Cli::Payment.new.process_features id: feature.id, cutoff: Time.now
    assert_equal BigMoney.new(3.544, :usd), Fundry::User::Commissions.get.balance, "Commission received"

    mailbox.clear
  end

  after do
    Peon.flush
  end

  it "should not email alerts when balance accounting is fine" do
    Fundry::Cli::Check.new(Fundry::User.repository.adapter).transfers
    assert_equal 0, mailbox.length, "mailbox is empty"
  end

  it "should find dodgy transfers and email alerts" do
    sql = <<-SQL
      INSERT INTO transfers (user_id, balance_amount, balance_currency, created_at, updated_at)
      VALUES (#{@donor2.id}, 10, 'usd', NOW(), NOW()) RETURNING id
    SQL

    result    = Fundry::Pledge.repository.adapter.execute sql
    transfer  = Fundry::Transfer.get result.insert_id

    expect = "ID: %-8d DATE: %s BALANCE: 10.00" % [ transfer.id, transfer.created_at ]

    Fundry::Cli::Check.new(Fundry::User.repository.adapter).transfers
    assert_equal 1, mailbox.length, "mailbox contains an alert"
    assert_match expect, mailbox.join(''), "mailbox contains dodgy ids"
  end
end
