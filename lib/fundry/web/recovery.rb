module Fundry
  class Web
    module Recovery
      def self.registered app
        app.get '/recover/new' do
          haml :'recover/new'
        end

        app.post '/recover' do
          if @user = User.recover(params[:identifier])
            if captcha_correct?
              haml :'recover/create'
            else
              flash.now[:error] = 'Failed captcha.'
              haml :'recover/new'
            end
          else
            identifier = params[:identifier] =~ /@/ ? 'Email' : 'Username'
            flash.now[:error] = "Profile #{identifier} '#{params[:identifier]}' doesn't exist."
            haml :'recover/new'
          end
        end

        app.get '/recover/:password_reset' do
          redirect absolute_secure_url(request.url) if request.scheme == 'http'
          @user = User.first(password_reset: params[:password_reset]) or raise Sinatra::NotFound
          haml :'/recover/edit'
        end

        app.put '/recover' do
          @user = User.first(password_reset: params[:user][:password_reset]) or raise Sinatra::NotFound
          if @user.update(password: params[:user][:password])
            login_as! @user
            flash[:success] = 'Profile details updated.'
            redirect url(:profile)
          else
            flash.now[:error] = 'There was an error updating your user account.'
            haml :'/recover/edit'
          end
        end
      end
    end # Recovery

    register Recovery
  end # Web
end # Fundry
