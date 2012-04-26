# Combined signup or signin + pledge or donate
module Fundry
  class Web
    module Combined
      module Helpers
        def setup_signup_deposit
          @amount = params['deposit'] ? params['deposit']['amount'].to_f : 0.0
          @paypal_fee, @paypal_cut = Payment.paypal_fees
        end

        def setup_signup_pledge
          setup_signup_deposit

          postsignup = session[:postsignup] || {}
          id         = postsignup[:feature]
          @feature   = id ? Feature.get(id) : Feature.new(params['feature'] || {})
          @feature or raise Sinatra::NotFound

          @project = Project.get(postsignup[:project]) || @feature.project
          @project or raise Sinatra::NotFound

          @balance = '%.2f' % (params['pledge'] ? params['pledge']['amount'] : postsignup[:amount] || 0.50).to_f
        end

        def setup_signup_donation
          setup_signup_deposit

          postsignup = session[:postsignup] || {}
          @project   = Project.get(postsignup[:project]) or raise Sinatra::NotFound
          @balance   = '0.50'

          if params['donation']
            @message   = params['donation']['message']
            @anonymous = params['donation']['anonymous']
            @balance   = '%.2f' % (params['donation']['amount'] || 0.50).to_f
          end
        end

        def setup_signup_project
          @project = Project.new(params['project'] || {})
        end

        def calculate_deposit_amount amount
          # NOTE: Since we don't know upfront what paypal will charge as fees, we're charging
          # a flat 3.4% fee and will credit the user what's left of the deposit minus actual
          # fees once paypal payment is finished.
          fee, cut = Payment.paypal_fees
          deposit  = amount.to_f

          # calculate basic paypal charges plus the charges for the additional amount we ask paypal,
          # if this confuses you stop using paypal.
          charges  = fee + deposit * cut/100.0
          deposit += charges + charges * cut/100.0
          deposit.round(2)
        end
      end # Helpers

      def self.registered app
        app.helpers Helpers

        app.get %r{/signup-(?<action>(pledge|donation|project))}x do |action|
          @user = User.new(subscription: {updates: true, reminders: true})
          send "setup_signup_#{action}"
          haml :"signup/#{action}"
        end

        app.post %r{/signup-(?<action>(pledge|donation))}x do |action|
          human  = captcha_correct?

          params['deposit'] = { 'amount' => calculate_deposit_amount(params[action]['amount']) }

          @user, errors = Profile.create(params, human)
          if errors.empty?
            session.delete(:forbidden)
            session.delete(:postsignup)
            flash[:analytics] = ['profile', 'create', @user.id.to_s]
            flash[:success]   = 'Profile created. You are now logged in.'

            login_as! @user
            internal_redirect :post, '/deposit', params
          else
            flash.now[:error] = '<ul>%s</ul>' % errors.map {|error| "<li>#{error}</li>"}.join('')
            send "setup_signup_#{action}"
            haml :"signup/#{action}"
          end
        end

        app.post %r{/signin-(?<action>(pledge|donation|project))}x do |action|
          params['deposit'] = { 'amount' => calculate_deposit_amount(params[action]['amount']) }

          user   = User.authenticate(params[:identifier], params[:password])
          errors = Profile.validate(params) + (user ? [] : [ 'Invalid username or password' ])
          errors << 'You have not accepted the Terms and Conditions' unless params['tc']

          if errors.empty?
            session.delete(:forbidden)
            session.delete(:postsignup)

            login_as! user
            case action
              when 'donation'
                internal_redirect :post, '/donation', params
              when 'pledge'
                if params[:feature][:id]
                  internal_redirect :post, "/feature/#{params[:feature][:id]}/pledge", params
                else
                  internal_redirect :post, '/feature', params
                end
              when 'project'
                internal_redirect :post, '/project', params
            end
          else
            @user = User.new
            flash.now[:error] = '<ul>%s</ul>' % errors.map {|error| "<li>#{error}</li>"}.join('')
            send "setup_signup_#{action}"
            haml :"signup/#{action}"
          end
        end

        app.post '/anonymous-donation' do
          params['deposit'] = { 'amount' => calculate_deposit_amount(params['donation']['amount']) }
          errors = Profile.validate(params)

          if errors.empty?
            user = User::Anonymous.get
            login_as! user
            internal_redirect :post, '/deposit', params
          else
            @user = User.new
            flash.now[:error] = '<ul>%s</ul>' % errors.map {|error| "<li>#{error}</li>"}.join('')
            send "setup_signup_donation"
            haml :"signup/donation"
          end
        end

        app.post '/signup-project' do
          human  = captcha_correct?
          @user, errors = Profile.create(params, human)
          if errors.empty?
            login_as! @user
            internal_redirect :post, '/project', params
          else
            flash.now[:error] = '<ul>%s</ul>' % errors.map {|error| "<li>#{error}</li>"}.join('')
            send "setup_signup_project"
            haml :"signup/project"
          end
        end

      end
    end # Combined

    register Combined
  end # Web
end # Fundry
