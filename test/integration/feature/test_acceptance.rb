require_relative '../helper'

describe "Feature Acceptance" do
  before do
    Peon.flush
    @developer = new_user
    @donor     = new_user balance: BigMoney.new(100, :usd)
    @project   = new_project user: @developer, name: 'Test project', web: 'http://www.example.com'
    @feature   = Fundry::Feature.create project: @project, name: 'Test feature', detail: 'blah'
    @donor.pledge @feature, BigMoney.new(10, :usd)
    @feature.feature_states.create(status: 'complete')
    @env  = { "rack.session" => { auth: @donor.id } }
  end

  after do
    job = Peon.dequeue
    assert job, "got a job on the queue"
    content = Yajl.load(job.body)["data"]
    job.delete
    assert_equal "donor_email", content["action"], "with a donor_email action"
    assert_equal "/job/feature/acceptance", content["resource"], "on a feature acceptance resource"
    assert_equal @feature.acceptances.first.id, content["id"], "with correct id"
    Peon.flush
  end

  def update_feature_acceptance_to state
    args = { acceptance: { state: state } }
    put "/feature/#{@feature.id}/acceptance/#{@feature.acceptances.first.id}", args, @env
    @feature.acceptances.reload
  end

  it "should create acceptance certificates pending approval for pledges on completed features" do
    assert_equal 1, @feature.acceptances.length
  end

  it "should mark a feature accepted when the correponding link is clicked" do
    @feature.acceptances.reload
    assert_equal 'pending', @feature.acceptances.first.state
    update_feature_acceptance_to 'accepted'
    assert_equal 302, last_response.status
    assert_equal "/feature/#{@feature.slug}", last_response.headers["Location"]
    assert_equal 'accepted', @feature.acceptances.first.state
  end

  it "should show approvals on the feature page" do
    update_feature_acceptance_to 'accepted'
    get "/feature/#{@feature.id}", {}, @env
    assert_match %r{<sup class='approvalsFace'>[\s\n]*1},  last_response.body
    assert_match %r{<sup class='rejectionsFace'>[\s\n]*0}, last_response.body
    assert_match %r{<sup class='pendingFace'>[\s\n]*0},    last_response.body
  end

  it "should mark a feature rejected when the correponding link is clicked" do
    @feature.acceptances.first.update(state: 'pending')
    update_feature_acceptance_to 'rejected'
    assert_equal 302, last_response.status
    assert_equal "/feature/#{@feature.slug}", last_response.headers["Location"]
    assert_equal 'rejected', @feature.acceptances.first.state
  end

  it "should throw a 400 on unknown action" do
    update_feature_acceptance_to 'linkbombed'
    assert_equal 400, last_response.status
  end

  it "should not allow changes outside the feedback interval" do
    acceptance = @feature.acceptances.first
    acceptance.update(state: 'pending', open: false)
    update_feature_acceptance_to 'accepted'
    assert_equal 302, last_response.status
    assert_match %r{expired}, @env["rack.session"][:__FLASH__][:error]
    assert_equal "/feature/#{@feature.slug}", last_response.headers["Location"]
    assert_equal 'pending', @feature.acceptances.first.state
  end

end
