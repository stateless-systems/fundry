require File.join(File.dirname(__FILE__), '..', 'fundry')
require 'haml'
require 'haml/engine/snowman'
require 'haml/filters/code'
require 'haml/filters/safedown'
require 'rack-flash'
require 'rack/encoder'
require 'rack/scheme'
require 'sinatra-auth'
require 'sinatra/base'
require 'sinatra/more'
require 'sinatra/pagination'
require 'sinatra/captcha'
require 'sinatra/bundles'

require 'big_money/serializer'
require 'big_money/parser_verbose'

require 'fundry/profile'
require 'fundry/search'

require 'pony-express'
require 'rack/showexceptions'

# TODO: I'm not sure how you are supposed to set the external encoding.
# It's UTF-8 already on OSX.
Encoding.default_internal = Encoding.default_external = "UTF-8"

# Workers for dispatched jobs.
require 'job/worker'

module Fundry
  # Web specific error message.
  class BalanceError < TransferError
    def message
      html =<<-HTML
        You do not have enough funds in your account. You can
        <a href="/deposit">deposit more funds</a> and try again.
      HTML
    end
  end

  class Web < Sinatra::Base

    STATIC_PAGE_TITLES = {
      'faq'      => 'Frequently asked questions',
      'terms'    => 'Terms & Conditions',
      'donation' => 'New donations',
      'comment'  => 'Recently added comments',
      'feature'  => 'Recently added features',
      'pledge'   => 'New pledges',
      'project'  => 'Crowdfunding for Software Development',
      'contact'  => 'Contact us'
    }


    SYSTEMS_MAIL_OPTIONS = {
      to:      'systems@localhost',
      from:    'fundry@fundry.com',
      via:     'sendmail'
    }

    # XXX: Add Google analytics keys.
    ANALYTICS_ACCOUNT = development? ? 'UA-XXX' : 'UA-XXX'

    # XXX: Add a secret cookie key.
    use Rack::Session::Cookie, key: 'fundry.session', secret: '-+.XXX.+)', expire_after: 86400
    use Rack::Flash
    use Rack::Encoder

    set :root, Fundry.root

    disable :raise_errors, :show_exceptions, :dump_errors

    enable  :methodoverride
    enable  :static, :logging, :dump_errors if development?

    register Sinatra::Pagination
    register Job::Worker

    # Auth.
    register Sinatra::Authentication
    register Sinatra::Authorization

    # ttl of captcha before user has to respond - 10s is an aggressive but reasonable value.
    set :captcha_ttl, 600
    # complexity 1 is simple, 4 is wicked hard (makes segmentation very difficult).
    set :captcha_level, 2
    register Sinatra::Captcha

    set :haml, escape_html: true

    set :js,  'js'
    set :css, 'css'
    register Sinatra::Bundles

    set :compress_bundles, false
    stylesheet_bundle :all, %w(base forms screen scrollable jquery.tipsy prettify)
    javascript_bundle :all, %w(jquery-1.4.4.min jquery.timeago jquery.bgpos fundry jquery.NobleCount.min
                               jquery.twitter jquery.cookie jquery.simplemodal-1.4 jquery.textarearesizer.min
                               jquery.tools.min jquery.tipsy jquery.formsy showdown)

    authenticate do
      user = Fundry::User.authenticate(params[:identifier], params[:password])
      if user
        user.update(client_ip: client_ip, last_login_at: Time.now)
        user.id
      else
        nil
      end
    end

    before do
      if authenticated?
        if user.suspended? or !user.active?
          flash[:error] = 'Your account has been suspended or deactivated.'
          session.delete(:auth)
          redirect url(:profile, user.slug)
        elsif request.scheme == 'http'
          redirect absolute_secure_url(request.url)
        end
      else
        response.delete_cookie(:nocache) if request.cookies.key?('nocache')
      end

      # Setup page titles that look unique for the sake of SEO :(
      @page_title = 'Crowdfunding for software development'
      path_info   = request.path_info.squeeze('/').strip

      if %r{^/.+}.match(path_info)
        path_stub   = path_info.split('/')[1].to_s.downcase
        @page_title = STATIC_PAGE_TITLES[path_stub] || path_stub.capitalize
      end

      content_type :html, charset: 'utf-8'
      expires(Time.now + 600) unless request.scheme == 'https'
    end

    helpers do
      # Fundry flavoured markdown.
      def markdown content
        Sanitize.clean(
          Haml::Filters::Markdown.render(content),
          elements:   %w{a b i ol ul li span div table thead th tbody td},
          attributes: {'a' => %w{href title}},
          protocols:  {'a' => %w{http https}}
        )
      end

      def no_cache
        headers.delete('Expires')
        headers.delete('Cache-Control')
      end
    end

    class ValidationError < ArgumentError; end
    #--
    # TODO move this to a helper!
    #
    # How about a 'pancake for sinatra apps' type deal (Composite/Delegate)? Downside would be your apps need to be
    # more loosely coupled (in terms of helpers and what not) which may or may not be a bad thing. Actually I get the
    # feeling I've seen a ticket + patch for this.
    #
    # Syntax:
    #   group %r{^ /profile /?}x, Fundry::Web::Profile
    #   group %r{^ /project /?}x, Fundry::Web::Project
    #
    # Or even in the same Sinatra app:
    #   group %r{^ /project}x do
    #     get '/' do
    #       ...
    #     end
    #   end

    Dir["#{root}/lib/fundry/web/*.rb"].each do |file|
      require file unless file =~ /hotshots/
    end

    def user
      # NOTE: IM appears to be busted in dm-core 1.1.0
      @_user ||= Fundry::User.get(session[:auth]) or raise Sinatra::NotAuthenticated
    end

    def client_ip
      (@env['HTTP_X_FORWARDED_FOR'] || @env['HTTP_CLIENT_IP'] || '').split(/, */).first
    end

    error do
      no_cache
      begin
        subject = 'Server made a boo boo'
        html    = Rack::ShowExceptions.new(self).pretty(@env, @env['sinatra.error']).first
        PonyExpress.mail SYSTEMS_MAIL_OPTIONS.merge(subject: subject, text: subject, html: html)
      rescue Exception => e
        # dont raise any exceptions here.
      end
      halt 500, 'Internal Server Error'
    end

    error Sinatra::NotFound do
      no_cache
      haml :not_found
    end

    error Sinatra::NotAuthenticated do
      no_cache
      session.delete(:auth)
      if request.path_info =~ %r{^/login}
        flash.now[:error] = "Invalid username or password." if request.request_method == 'POST'
        error 401, haml(:login)
      else
        redirect absolute_secure_url('/login')
      end
    end

    error Sinatra::NotAuthorized do
      no_cache
      if authenticated?
        error 403, haml(:unauthorized)
      else
        session.delete(:auth)
        redirect absolute_secure_url('/login')
      end
    end

  end # Web
end # Fundry
