require_relative '../helper'
require 'job/dispatcher'
require 'thin'

describe "Job Dispatcher and Emailer" do
  before do
    Peon.flush
    email = "#{Etc.getpwuid.name}@localhost"
    @someguy   = new_user
    @developer = new_user
    @donor     = new_user balance: BigMoney.new(100, :usd), email: email
    @project   = new_project user: @developer, name: 'Test project', web: 'http://www.example.com'
    @feature   = Fundry::Feature.create project: @project, name: 'Test feature', detail: 'blah'
    @env       = { "rack.session" => { auth: @donor.id } }
    @donor.pledge @feature, BigMoney.new(10, :usd)
  end

  after do
    Peon.flush
    mailbox.clear
  end

  it "should dispatch the job to worker and have an acceptance email sent out" do
    @feature.feature_states.create(status: 'complete')
    myapp = clone_app_with_logger Fundry::Web
    Rack::Test::App.run myapp, port: 12345 do
      dispatcher = Job::Dispatcher.new "/dev/null", host: "127.0.0.1", port: "12345"
      Thread.new { dispatcher.run { EM.stop }; sleep 5 }.join
    end

    req, res = myapp.logs.first

    assert_equal "/job/feature/acceptance/#{@feature.acceptances.first.id}/donor_email", req["REQUEST_PATH"]
    assert_equal 200, res[0], "Dispatched job to worker successfully"

    mail = mailbox.join('')
    assert_match %r{Fred Nerk}, mail, "Local mailbox contains the dispatched email"
  end

  it "should dispatch the job to worker and have a refund email sent out" do
    @feature.feature_states.create(status: 'rejected')
    myapp = clone_app_with_logger Fundry::Web
    Rack::Test::App.run myapp, port: 12345 do
      dispatcher = Job::Dispatcher.new "/dev/null", host: "127.0.0.1", port: "12345"
      Thread.new { dispatcher.run { EM.stop }; sleep 5 }.join
    end

    req, res = myapp.logs.first

    assert_equal "/job/pledge/#{@feature.pledges.first.id}/notify-donor", req["REQUEST_PATH"]
    assert_equal 200, res[0], "Dispatched job to worker successfully"

    mail = mailbox.join('')
    assert_match %r{Fred Nerk.*marked.*rejected}m, mail, "Local mailbox contains the dispatched email"
    assert_match %r{pledge of.*?10\.00USD}, mail, "mail contains proper refund amount"
  end

  it "should dispatch the job to worker and have a pledge retraction email sent out" do
    delete "/feature/#{@feature.id}/pledge", {}, @env
    assert_equal 302, last_response.status, "redirects to feature page"
    assert_match %r{pledge retracted}i, @env["rack.session"][:__FLASH__][:success]

    myapp = clone_app_with_logger Fundry::Web
    Rack::Test::App.run myapp, port: 12345 do
      dispatcher = Job::Dispatcher.new "/dev/null", host: "127.0.0.1", port: "12345"
      Thread.new { dispatcher.run { EM.stop }; sleep 5 }.join
    end

    req, res = myapp.logs.first

    assert_equal "/job/pledge/#{@feature.pledges.first.id}/notify-owner", req["REQUEST_PATH"]
    assert_equal 200, res[0], "Dispatched job to worker successfully"

    mail = mailbox.join('')
    assert_match %r{Fred Nerk.*retracted}m, mail, "Local mailbox contains the dispatched email"
    assert_match %r{pledge of.*?10\.00USD}, mail, "mail contains proper refund amount"
  end

  # TODO should we throw a 403 Forbidden instead ?
  it "should make sure user is authenticated to delete a pledge" do
    delete "http://localhost:12345/feature/#{@feature.id}/pledge", {}, { "rack.session" => { auth: @someguy.id } }
    assert_equal 404, last_response.status, "throws a 404"
  end
end
