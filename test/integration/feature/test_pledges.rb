require_relative '../helper'

describe "Feature Pledges" do
  before do
    @developer = new_user
    @project   = new_project user: @developer, name: 'Test project', web: 'http://www.example.com'
    @feature   = Fundry::Feature.create project: @project, name: 'Test feature', detail: 'blah'
    @donor     = new_user balance: BigMoney.new(100, :usd)
    @env       = { "rack.session" => { auth: @donor.id } }

    @project.update(verified: true)
  end

  it "should process a pledge" do
    balance = @feature.balance
    post "/feature/#{@feature.id}/pledge", { pledge: { amount:  10 } }, @env
    assert_equal 302, last_response.status, "redirects to feature page"
    assert_equal balance + 10, Fundry::Feature.get(@feature.id).balance, "feature balance updated to $10"
    get "/feature/#{@feature.id}", {}, @env
    assert_match %r{Your pledge}i, last_response.body, "pledge message shown"
    assert_match %r{retract}i,     last_response.body, "retract pledge message shown"
  end

  it "should add to existing pledge on re-pledge" do
    @donor.pledge @feature, BigMoney.new(2.50, :usd)
    post "/feature/#{@feature.id}/pledge", { pledge: { amount:  10 } }, @env
    assert_equal 302, last_response.status, "redirects to feature page"
    assert_equal 10.0, Fundry::Feature.get(@feature.id).balance.to_f, "feature balance updated to $10"
    assert_equal 1, @feature.pledges_by_user_id(@donor.id).length, "new pledge overwrites the old one"
    Fundry::Pledge.with_deleted do
      pledges = @feature.pledges_by_user_id(@donor.id)
      assert pledges.select(&:deleted_at).first, "and old one is marked deleted"
      assert pledges.reject(&:deleted_at).first, "new one is marked deleted"
    end

    assert_equal 90.0, Fundry::User.get(@donor.id).balance.to_f
  end

  it "should fail with error on pledges with no monies in the account" do
    balance = @feature.balance
    post "/feature/#{@feature.id}/pledge", { pledge: { amount:  200 } }, @env
    assert_equal 200, last_response.status, "displays feature page"
    assert_equal balance, Fundry::Feature.get(@feature.id).balance, "feature balance stays same at $0"
    assert_match %r{not have enough funds in your account}, last_response.body, "and displays error message"
  end

end
