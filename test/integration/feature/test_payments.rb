require_relative '../helper'

describe "Feature Payments" do
  before do
    require 'fundry/cli/payment'
    Peon.flush
    @developer = new_user
    @project   = new_project user: @developer, name: 'Test project', web: 'http://www.example.com'
    @feature   = Fundry::Feature.create project: @project, name: 'Test feature', detail: 'blah'
    @donors    = (1..3).map {|n| new_user balance: BigMoney.new(100, :usd) }
    @donors.each {|donor| donor.pledge @feature, BigMoney.new(10, :usd) }
    @feature.feature_states.create(status: 'complete')
  end

  after do
    Peon.flush
  end

  def update_feature_acceptance_to id, state
    @feature.acceptances(id: id).first.update(state: state)
    @feature.acceptances.reload
  end

  def accept_feature *donors
    donors[0..1].each do |donor|
      acceptance = donor.transfers.pledges.first.acceptance
      update_feature_acceptance_to acceptance.id, "accepted"
    end
  end

  def reject_feature *donors
    donors[0..1].each do |donor|
      acceptance = donor.transfers.pledges.first.acceptance
      update_feature_acceptance_to acceptance.id, "rejected"
    end
  end

  it "should process approval & rejection payments" do
    reject_feature *@donors[0..1]
    accept_feature @donors[2]

    Fundry::Cli::Payment.new.process_features cutoff: Time.now

    assert_equal BigMoney.new(9.50, :usd), Fundry::User.get(@developer.id).balance,
                 "Geek's got the dough (minus commission)"

    (0..1).each do |n|
      donor = Fundry::User.get(@donors[n].id)
      assert_equal BigMoney.new(100, :usd), donor.balance, "Donor #{donor.name} got back the pledge monies"
    end

    donor = Fundry::User.get(@donors.last.id)
    assert_equal BigMoney.new(90, :usd), donor.balance, "Donor #{donor.name} paid out the pledge monies"

    feature = Fundry::Feature.get(@feature.id)
    assert_equal BigMoney.new(10, :usd), feature.balance, "feature balance drops down after refunds"
  end


  it "should ignore rejections in the minority" do
    reject_feature @donors[0]
    accept_feature *@donors[1..2]

    Fundry::Cli::Payment.new.process_features cutoff: Time.now

    assert_equal BigMoney.new(28.50, :usd), Fundry::User.get(@developer.id).balance,
                 "Geek's got all the dough (minus commissions)"

    (0..2).each do |n|
      donor = Fundry::User.get(@donors[n].id)
      assert_equal BigMoney.new(90, :usd), donor.balance, "Donor #{donor.name} paid out the pledge monies"
    end

    feature = Fundry::Feature.get(@feature.id)
    assert_equal BigMoney.new(30, :usd), feature.balance, "feature balance stays same"
  end


  it "should refund all pledges on developer marking feature as rejected" do
    # HACK: bypass feature state validation and reject a feature marked completed just to test it.
    # DO NOT EVER UPDATE FEATURE STATE directly.
    @feature.update state: 'rejected'
    (0..2).each do |n|
      donor = Fundry::User.get(@donors[n].id)
      assert_equal BigMoney.new(100, :usd), donor.balance, "Donor #{donor.name} got money back"
    end
    assert_equal BigMoney.new(0, :usd), Fundry::Feature.get(@feature.id).balance, "feature balance is $0"
  end
end
