require_relative '../helper'

describe "Periodic Project Verification" do
  before do
    require 'fundry/cli/project'
    Peon.flush
    @developer = new_user
    @project   = new_project user: @developer, name: 'Test project', web: 'http://www.example.com'
    @project.cache.delete(@project.verification_key)
  end

  after do
    Peon.flush
    @project.cache.delete(@project.verification_key)
  end

  it "should queue project for daily verification" do
    @project.update(created_at: Time.now - 86400 - 300)
    do_daily_checks
    check_queue
    do_daily_checks
    assert_equal 0, Peon.stats(:tube, 'fundry')["current-jobs-ready"], 'does not immediately re-queue'
  end

  it "should queue project for weekly verification" do
    @project.update(created_at: Time.now - 86400*8)
    do_weekly_checks
    check_queue
    do_weekly_checks
    assert_equal 0, Peon.stats(:tube, 'fundry')["current-jobs-ready"], 'does not immediately re-queue'
  end

  def check_queue
    expect = {
      action: "verify", resource: "/job/project", id: @project.id,
      params: { uri: "http://www.fundry.com/project/#{@project.slug}" }
    }
    message = Peon.dequeue.body
    assert_equal expect, Yajl::Parser.new(symbolize_keys: true).parse(message)[:data]
  end

  def do_daily_checks
    Fundry::Cli::Project.new.verify 'http://www.fundry.com', Time.now - 86400, Time.now - 86400*7
  end

  def do_weekly_checks
    Fundry::Cli::Project.new.verify 'http://www.fundry.com', Time.now - 86400*7, Time.at(0)
  end
end
