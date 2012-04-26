require_relative '../helper'

describe 'User::Meta updates' do
  before do
    @user      = new_user
    @payment   = @user.deposit BigMoney.new('10', :usd)
    @payment.complete!

    @developer = new_user
    @project   = new_project user: @developer, name: 'Test project', web: 'http://127.0.0.1:12346'
    @project.update verified: true
  end

  it 'must update donation meta' do
    @user.donate @project, BigMoney.new(1.25, :usd)
    assert_equal 1, @user.meta.donation
    assert_equal 1.25, @user.meta.donation_balance.to_f
  end

  it 'must update pledge meta - approval' do
    feature = Fundry::Feature.create(project: @project, name: 'test', detail: 'test', url: 'http://fundry.local')
    @user.pledge feature, BigMoney.new(0.50, :usd)
    assert_equal 1, @user.meta.pledge, 'pledges count'
    assert_equal 1, @user.meta.pledge_pending, 'pledges pending count'
    assert_equal 0.5, @user.meta.pledge_pending_balance.to_f, 'pledge pending balance'
    assert_equal 0.0, @user.meta.pledge_complete_balance.to_f, 'pledge complete balance'

    feature.feature_states.create(status: 'complete')
    feature.acceptances.all.update(state: 'accepted')
    feature.finalize!

    @user = Fundry::User.get(@user.id)
    assert_equal 0, @user.meta.pledge_pending, 'pending pledges'
    assert_equal 1, @user.meta.pledge_approval, 'approved pledges'

    assert_equal 1, @developer.meta.pledge_complete, 'completed pledges'
    assert_equal 0.5, @developer.meta.pledge_complete_balance.to_f, 'completed pledges balance'
  end

  it 'must update pledge meta - objection' do
    feature = Fundry::Feature.create(project: @project, name: 'test', detail: 'test', url: 'http://fundry.local')
    @user.pledge feature, BigMoney.new(0.50, :usd)
    assert_equal 1, @user.meta.pledge, 'pledges count'
    assert_equal 1, @user.meta.pledge_pending, 'pledges pending count'
    assert_equal 0.5, @user.meta.pledge_pending_balance.to_f, 'pledge pending balance'
    assert_equal 0.0, @user.meta.pledge_complete_balance.to_f, 'pledge complete balance'

    feature.feature_states.create(status: 'complete')
    feature.acceptances.all.update(state: 'rejected')
    feature.finalize!

    @user = Fundry::User.get(@user.id)
    assert_equal 0, @user.meta.pledge_pending, 'pending pledges'
    assert_equal 0, @user.meta.pledge_approval, 'approved pledges'
    assert_equal 1, @user.meta.pledge_objection, 'pledge objections'

    assert_equal 1, @developer.meta.pledge_complete, 'completed pledges'
    assert_equal 0, @developer.meta.pledge_complete_balance.to_f, 'completed pledges balance'
  end

  it 'must update withdrawn meta' do
    payment = @user.withdraw BigMoney.new(5, :usd)
    assert_equal 5, @user.meta.withdrawn_balance.to_f, 'withdrawn balance on withdraw'

    payment.complete!
    assert_equal 5, @user.meta.withdrawn_balance.to_f, 'withdrawn balance on complete'

    payment = @user.withdraw BigMoney.new(2, :usd)
    assert_equal 7, @user.meta.withdrawn_balance.to_f, 'withdrawn balance on withdraw'

    payment.reject!
    assert_equal 5, @user.meta.withdrawn_balance.to_f, 'withdrawn balance on reject'
  end

  it 'must restore meta on pledge retraction' do
    feature = Fundry::Feature.create(project: @project, name: 'test', detail: 'test', url: 'http://fundry.local')
    @user.pledge feature, BigMoney.new(0.50, :usd)

    assert_equal 1,   @user.meta.pledge, 'pledges count'
    assert_equal 1,   @user.meta.pledge_pending, 'pledges pending count'
    assert_equal 0.5, @user.meta.pledge_pending_balance.to_f,  'pledge pending balance'
    assert_equal 0.0, @user.meta.pledge_complete_balance.to_f, 'pledge complete balance'

    assert_equal 1,   feature.project.meta.pledge, 'project pledges'
    assert_equal 1,   feature.project.meta.pledge_pending, 'project pledge pending'
    assert_equal 0.5, feature.project.meta.pledge_pending_balance.to_f, 'project pledge pending balance'

    feature.pledges_by_user_id(@user.id).first.retract!

    @user = Fundry::User.get(@user.id)
    assert_equal 0, @user.meta.pledge_pending, 'pending pledges after retract!'
    assert_equal 0, @user.meta.pledge_approval, 'approved pledges after retract!'
    assert_equal 0, @user.meta.pledge_objection, 'pledge objections after retract!'

    meta = Fundry::ProjectMeta.get(feature.project.id)
    assert_equal 0, meta.pledge, 'project pledges after retract!'
    assert_equal 0, meta.pledge_pending, 'project pledge pending after retract!'
    assert_equal 0, meta.pledge_pending_balance.to_f, 'project pledge pending balance after retract!'

    assert_equal 0, @developer.meta.pledge_complete, 'completed pledges'
    assert_equal 0, @developer.meta.pledge_complete_balance.to_f, 'completed pledges balance'
  end
end
