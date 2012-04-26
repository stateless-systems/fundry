module Fundry
  class Web
    module Profiles
      module Helpers
        def gravatar_url user, size
          ssl = request.scheme == 'https'
          user.gravatar_url(size, ssl) + '&d=%s' % absolute_url('art/images/defaultAvatar.png')
        end

        def unsubscribe_url user, service
          "https://fundry.com/unsubscribe/#{user.subscription.token}/#{service}"
        end

        def validate_password_change!
          errors = []
          args   = params.delete('password')
          errors << 'Incorrect current password, try again' unless user.password == user.digest_password(args['old'])
          errors << 'Please re-type the new password correctly' unless args['new'] == args['confirm']
          errors << 'New password must be atleast 8 characters in length' unless args['new'] && args['new'].length >= 8

          if errors.empty?
            params['user']['password'] = args['new']
          else
            flash.now[:error] = errors.length > 1 ?
              '<ul>%s</ul>' % errors.map {|e| "<li>#{e}</li>"}.join('')
              : errors.first
            halt 200, haml(:"profile/edit")
          end
        end

        def account_deactivation_feedback user, feedback
          message = <<-TEXT
            The profile https://fundry.com/profile/#{user.slug} has been deactivated by the owner.

            Feedback: #{feedback}
          TEXT

          PonyExpress.mail to:      'fundry+deletion@fundry.com',
                           from:    "user+#{user.username}@fundry.com",
                           subject: 'Account deactivation',
                           text:    message,
                           via:     :sendmail,
        end
      end # Helpers

      def self.registered app
        app.helpers Helpers

        app.get '/profile/inbox' do
          authenticate!
          @user = user
          haml :"profile/inbox"
        end

        app.get '/profile/inbox/:id' do |id|
          authenticate!
          @user  = user
          @email = user.emails(id: id).first or raise Sinatra::NotFound
          haml :"profile/_email", layout: false
        end

        app.delete '/profile/inbox' do
          authenticate!
          @user  = user
          ids    = params['email']
          user.emails(id: ids).destroy
          flash[:success] = 'Deleted emails.'
          redirect '/profile/inbox'
        end

        app.get '/profile/deactivate' do
          authenticate!
          @errors = user.deactivation_errors

          flash.now[:error] = 'There was an error trying to deactivate your account.' unless @errors.empty?
          haml :"profile/deactivate"
        end

        app.delete '/profile' do
          authenticate!
          errors = user.deactivation_errors

          unless errors.empty?
            flash[:error] = '<ul>%s</ul>' + errors.values.map{|e| "<li>#{e.first}</li>"}.join('')
            redirect '/profile'
          end

          account_deactivation_feedback(user, params['feedback']) if (params['feedback'] || '').length > 0

          user.update(deactivated_at: Time.now)
          flash[:success] = 'Your profile has been deactivated.'
          redirect '/logout'
        end

        app.get '/profile/new' do
          redirect '/profile' if authenticated?
          redirect absolute_secure_url(:profile, :new) if request.scheme != 'https'
          @user = User.new(subscription: {updates: true, reminders: true})
          haml :'/profile/new'
        end

        # TODO do we need this catch all /profile/:id route ?
        app.get %r{^ /profile (?:/(?<id>\d+)) /? $}x do |id|
          @user = User.get(id) or raise Sinatra::NotFound
          redirect url(:profile, @user.slug)
        end

        app.get %r{^ /profile (?:/(?<id>\d+)) /(?<tab>pledge|donation|comment) /? $}x do |id, tab|
          @user = User.get(id) or raise Sinatra::NotFound
          redirect url(:profile, @user.slug, tab)
        end

        app.get %r{^ /profile (?:/(?<name>[%[:alpha:]][^/]+))? /(?<tab>pledge|donation|comment) /? $}x do |name, tab|
          authenticate! if name.blank?
          @user = (name.blank? ? User.get(session[:auth]) : User.first(username: URI.decode(name))) or
            raise Sinatra::NotFound

          raise Sinatra::NotFound if @user.group?(:system)
          @tab  = tab || 'pledge'
          haml :"profile/#{@tab}"
        end

        app.get '/profile/edit' do
          authenticate!
          haml :'/profile/edit'
        end

        app.put '/profile' do
          authenticate!
          booleanize! :user, :subscription, :updates,   params
          booleanize! :user, :subscription, :reminders, params

          params['user'].delete('password')
          if params[:password] && params[:password][:new] && params[:password][:new].length > 0
            validate_password_change!
          end

          if user.update(params['user'])
            flash[:success] = 'Profile updated.'
            redirect url(:profile)
          else
            flash.now[:error] = validation_errors user, 'There was an error updating your profile.'
            haml :'/profile/edit'
          end
        end

        app.post '/profile' do
          redirect '/profile' if authenticated?
          human = captcha_correct?

          booleanize! :user, :subscription, :updates,   params
          booleanize! :user, :subscription, :reminders, params

          @user, errors = Profile.create(params, human)
          if errors.empty?
            session.delete(:forbidden)
            session.delete(:postsignup)
            flash[:analytics] = ['profile', 'create', @user.id.to_s]
            flash[:success]   = 'Profile created. You are now logged in.'

            login_as! @user

            if params.include?('deposit')
              internal_redirect :post, '/deposit', params
            else
              redirect absolute_url(:profile)
            end
          else
            flash.now[:error] = '<ul>%s</ul>' % errors.map {|error| "<li>#{error}</li>"}.join('')
            haml :"profile/new"
          end
        end

        app.put %r{^ /profile/ (?<id>\d+) /suspend $}x do |id|
          authenticate!
          user.admin? or raise Sinatra::NotFound
          profile_user = User.get(id) or raise Sinatra::NotFound
          profile_user.suspend!
          flash[:success] = 'User has been suspended.'
          redirect "/profile/#{profile_user.slug}"
        end

        app.put %r{^ /profile/ (?<id>\d+) /unsuspend $}x do |id|
          authenticate!
          user.admin? or raise Sinatra::NotFound
          profile_user = User.get(id) or raise Sinatra::NotFound
          profile_user.unsuspend!
          flash[:success] = 'User has been unsuspended.'
          redirect "/profile/#{profile_user.slug}"
        end

        app.get %r{^ /unsubscribe /(?<token>[a-z0-9]+) /(?<service>\w+) $}x do |token, service|
          subscription = Subscription.first(token: token) or raise Sinatra::NotFound
          if subscription.update(Hash[service, false])
            flash[:success] = "Your notification preferences have been updated."
          else
            flash[:error] = "There was an error updating your notification preferences."
          end
          redirect "/profile/#{subscription.user.slug}"
        end

        app.get %r{^ /profile (?:/(?<name>[%[:alpha:]][^/]+))? /activity (?:\.(?<format>rss))? /? $}x do |name, format|
          redirect '/' if name.blank? and !session[:auth]
          @user = (name.blank? ? User.get(session[:auth]) : User.first(username: URI.decode(name))) or
            raise Sinatra::NotFound

          raise Sinatra::NotFound if @user.group?(:system)
          case format
            when /rss/i
              content_type 'application/rss+xml', charset: 'utf-8'
              haml :'profile/activity.rss', layout: false
            else haml :'profile/activity'
          end
        end

        app.get %r{^ /profile (?:/(?<name>[%[:alpha:]][^/]+))? /? $}x do |name|
          redirect '/' if name.blank? and !session[:auth]
          @user = (name.blank? ? User.get(session[:auth]) : User.first(username: URI.decode(name))) or
            raise Sinatra::NotFound
          internal_redirect :get, url(:profile, @user.slug, :pledge)
        end
      end
    end # Profiles

    register Profiles
  end # Web
end # Fundry
