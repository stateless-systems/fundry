require_relative '../helper'
require 'job/dispatcher'
require 'thin'

describe "Suspension and Unsuspension" do
  before do
    Peon.flush
    email = "#{Etc.getpwuid.name}@localhost"
    @user = new_user
  end

  after do
    Peon.flush
    mailbox.clear
  end

  it "should dispatch the job to worker and have a suspension email sent" do
    @user.suspend!
    myapp = clone_app_with_logger Fundry::Web
    Rack::Test::App.run myapp, port: 12345 do
      dispatcher = Job::Dispatcher.new "/dev/null", host: "127.0.0.1", port: "12345"
      Thread.new { dispatcher.run { EM.stop }; sleep 5 }.join
    end

    req, res = myapp.logs.first

    assert_equal "/job/user/#{@user.id}/suspend-email", req["REQUEST_PATH"]
    assert_equal 200, res[0], "Dispatched job to worker successfully"

    mail = mailbox.join('')
    assert_match %r{has been suspended}i, mail, "local mailbox contains the dispatched email"
  end


  it "should dispatch the job to worker and have a unsuspension email sent" do
    @user.update(suspended_at: Time.now)
    @user.unsuspend!
    myapp = clone_app_with_logger Fundry::Web
    Rack::Test::App.run myapp, port: 12345 do
      dispatcher = Job::Dispatcher.new "/dev/null", host: "127.0.0.1", port: "12345"
      Thread.new { dispatcher.run { EM.stop }; sleep 5 }.join
    end

    req, res = myapp.logs.first

    assert_equal "/job/user/#{@user.id}/unsuspend-email", req["REQUEST_PATH"]
    assert_equal 200, res[0], "Dispatched job to worker successfully"

    mail = mailbox.join('')
    assert_match %r{has been unsuspended}i, mail, "local mailbox contains the dispatched email"
  end
end
