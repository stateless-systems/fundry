require_relative '../helper'

describe "Feature State" do
  before do
    @developer = new_user
    @project   = new_project user: @developer, name: 'Test project', web: 'http://www.example.com'
    @feature   = Fundry::Feature.create project: @project, name: 'Test feature', detail: 'blah'
    @env       = { "rack.session" => { auth: @developer.id } }
    @feature.feature_states.create(status: 'complete')
  end

  after do
    Peon.flush
  end

  it "should not allow status change after a feature is marked complete" do
    post "/feature/#{@feature.id}/state", { state: { status: 'new' } }, @env
    assert_equal 302, last_response.status, "redirects to feature page"
    assert_match %r{already.*marked.*complete}, @env["rack.session"][:__FLASH__][:error], "shows error message"
  end
end
