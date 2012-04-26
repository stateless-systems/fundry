require_relative '../helper'
require 'job/dispatcher'
require 'thin'

describe 'Project Verification' do
  before do
    Peon.flush
    @developer = new_user
    @project   = new_project user: @developer, name: 'Test project', web: 'http://127.0.0.1:12346'
    @env       = { 'rack.session' => { auth: @developer.id }, 'SERVER_NAME' => '127.0.0.1' }
    @site_html = <<-HTML
      <html>
        <body>
          <a href="http://127.0.0.1/project/#{@project.slug}">project</a>
        </body>
      </html>
    HTML
    @project.cache.delete(@project.verification_key)
  end

  after do
    Peon.flush
    @project.cache.delete(@project.verification_key)
  end

  it 'should dispatch the job to worker and verify the project' do
    put "http://127.0.0.1/project/#{@project.id}/verify", {}, @env
    req, res = do_verification @site_html

    assert_equal "/job/project/#{@project.id}/verify", req['REQUEST_PATH']
    assert_equal 200, res[0], 'Dispatched job to worker successfully'

    project = Fundry::Project.get(@project.id)

    # all verifications are manual for now.
    assert_equal false, project.verified, 'and project has still been marked unverified'
    assert_equal 10, project.verifications.first.rank, 'verification rank = 10 for anchor check'
  end

  it 'should requeue when verification fails' do
    put "/project/#{@project.id}/verify", {}, @env
    req, res = do_verification 'blraagh'

    assert_equal "/job/project/#{@project.id}/verify", req['REQUEST_PATH']
    assert_equal 503, res[0], 'Verification failed with 503'
    assert_equal '300', res[1]['Retry-After'], 'Retry-After 300s'
    assert_equal false, Fundry::Project.get(@project.id).verified, 'and project is still unverified'
    assert_equal 1, Peon.stats(:tube, 'fundry')['current-jobs-delayed'], '1 delayed verification job'
  end

  it 'should email reminder out if the project unverified and is a day old or older than a week' do
    [ Time.now - 86400 - 3600, Time.now - 86400*8 ]. each do |ts|
      mailbox.clear
      Peon.flush
      @project.update(created_at: ts)
      @project.cache.delete(@project.verification_key)

      put "/project/#{@project.id}/verify", {}, @env
      @project.cache.store(@project.verification_key, 6)
      req, res = do_verification 'blargh'

      assert_equal 500, res[0], 'Verification failed with 500'
      assert_match %r{not been verified yet}i, mailbox.join(''), "found verification reminder when created_at = #{ts}"
      assert_match %r{Unsubscribe:.*https}i,   mailbox.join(''),  'has unsubscribe link'
    end
  end

  it 'should not email reminder for projects newer than a day or resend one when newer than week' do
    [ Time.now - 86200, Time.now - 86400*3 ]. each do |ts|
      mailbox.clear
      Peon.flush
      @project.update(created_at: ts)
      @project.cache.delete(@project.verification_key)

      put "/project/#{@project.id}/verify", {}, @env
      @project.cache.store(@project.verification_key, 6)
      req, res = do_verification 'blargh'

      assert_equal 500, res[0], 'Verification failed with 500'
      assert_equal 0, mailbox.length, "no verification reminder when created_at = #{ts}"
    end
  end

  it 'should fail verification on redirect to new host' do
    put "/project/#{@project.id}/verify", {}, @env
    req, res = do_verification @site_html, 302, { 'Location' => 'http://www.www.google.com' }

    assert_equal "/job/project/#{@project.id}/verify", req['REQUEST_PATH']
    assert_equal 503, res[0], 'Verification failed with 503'
    assert_equal '300', res[1]['Retry-After'], 'Retry-After 300s'
  end


  def do_verification html, status = 200, headers = {}
    host = '127.0.0.1'

    pid = fork do
      handler = proc { [ status, headers, [ html ] ] }
      Thin::Logging.silent = true
      Thin::Server.start handler, host, 12346
    end

    myapp = clone_app_with_logger Fundry::Web
    Rack::Test::App.run myapp, port: 12345 do
      dispatcher = Job::Dispatcher.new '/dev/null', host: host, port: 12345
      Thread.new { dispatcher.run { EM.add_timer(1) { EM.stop } }; sleep 5 }.join
    end

    myapp.logs.first

    ensure
      Process.kill 'TERM', pid
      Process.wait pid
  end
end
