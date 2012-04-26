require_relative '../helper'
require 'rack/test'
require 'rack/test/app'
require 'pony-express'
require 'pony-express/test'
require 'fundry/web'

class MiniTest::Unit::TestCase
  include Rack::Test::Methods
  include PonyExpress::Test

  def clone_app_with_logger myapp, opts={}
    klass = Class.new(myapp) do
      disable :logging

      def self.logs
        @logs ||= []
      end

      def call env
        res = super(env.merge(self.class.env))
        self.class.logs << [ env, res ]
        res
      end

      class << self; attr_accessor :env; end
    end

    klass.env = opts[:env] || {}
    klass
  end

  def new_paypal_mechanize_agent
    mech = Mechanize.new do |agent|
      agent.user_agent          = 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.5pre)'
      agent.follow_meta_refresh = true
      agent.redirect_ok         = true
      agent.redirection_limit   = 10
    end
    mech.get('https://developer.paypal.com').form_with(name: 'login_form') do |form|
      form.login_email    = 'shane@statelesssystems.com'
      form.login_password = 'han101776'
    end.submit
    mech
  end

  def app
    klass = Class.new(Fundry::Web)
    klass.disable :sessions
    klass
  end

  # overriden verbs to pass dummy session info.
  def get path, args={}, env={}
    env["rack.session"] ||= {}
    super(path, args, env.merge('rack.url_scheme' => 'https'))
  end

  def post path, args={}, env={}
    env["rack.session"] ||= {}
    super(path, args, env.merge('rack.url_scheme' => 'https'))
  end

  def delete path, args={}, env={}
    env["rack.session"] ||= {}
    super(path, args, env.merge('rack.url_scheme' => 'https'))
  end

  def put path, args={}, env={}
    env["rack.session"] ||= {}
    super(path, args, env.merge('rack.url_scheme' => 'https'))
  end
end
