module Fundry
  class Web
    module Authentication
      module Helpers
        def authenticate! success = request.url, message = nil
          if authenticated?
            response.set_cookie(:nocache, 1)
            redirect(absolute_secure_url(session.delete(:forbidden) || '/profile')) if request.path_info =~ %r{^/login}
          else
            if session.key?(:forbidden)
              homepage, loginpage = absolute_url(''), absolute_url('login')
              session[:forbidden] = success unless [ homepage, loginpage ].include?(success)
            else
              session[:forbidden] = success
            end

            flash[:info]   = message if message
            session[:auth] = authenticate or raise Sinatra::NotAuthenticated

            # TODO why isn't there a delete ?
            flash.flag! && flash.sweep!

            authenticate! message
          end
        end

        def absolute_secure_url *path
          path = path.join('/').sub(%r{^(?:https?://[^/]+)?/?}i, '')
          'https://%s/%s' % [ request.host, path ]
        end

        def absolute_insecure_url *path
          path = path.join('/').sub(%r{^(?:https?://[^/]+)?/?}i, '')
          'http://%s/%s'  % [ request.host, path ]
        end

        def login_as! user
          session[:auth] = user.id
          response.set_cookie(:nocache, 1)
        end
      end # Helpers

      def self.registered app
        app.helpers Helpers

        # Signup is a separate route to make sure any sticky session variables setup
        # for combined signup, deposit, pledge or donate doesn't interfere.
        app.get '/signup' do
          redirect '/profile' if authenticated?
          session.delete(:forbidden)
          session.delete(:postsignup)
          @user = User.new(subscription: {updates: true, reminders: true})
          haml :"profile/new"
        end

        app.get '/login/nc' do
          session.delete(:postsignup)
          redirect absolute_secure_url(:login)
        end

        # TODO find a cleaner way to replace said route.
        app.routes['GET'] -= [ app.routes['GET'].find {|r| r[0] == %r{^/logout/?$} } ]
        app.routes['GET'] -= [ app.routes['GET'].find {|r| r[0] == %r{^/login/?$}  } ]

        app.get '/logout/?' do
          response.delete_cookie(:nocache)
          session.delete(:auth)
          redirect absolute_insecure_url(request.referrer)
        end

        app.get '/login/?' do
          redirect '/profile' if authenticated?
          if session.key?(:postsignup)
            redirect '/signup-%s' % session[:postsignup][:action]
          end
          haml :login
        end
      end
    end # Authentication

    register Authentication
  end # Web
end # Fundry
