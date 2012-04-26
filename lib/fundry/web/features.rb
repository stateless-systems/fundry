# All feature related request handling.
module Fundry
  class Web
    module Features
      module Helpers
        def feature_editable? feature
          pledges = feature.pledges.length
          pledge  = feature.pledges(order: :created_at, limit: 1).first
          project = @feature.project

          (pledges == 1 && authorized?(pledge.transfer.user_id)) || (pledges == 0 && authorized?(project.user_id))
        end
      end # Helpers

      def self.registered app
        app.helpers Helpers

        app.get '/feature' do
          @tab      = 'feature'
          @features = params[:order] == 'new' \
            ? Feature.all(order: [:created_at.desc], :state.not => 'rejected') \
            : Feature.top
          haml :feature
        end

        app.get %r{^ /feature (?:/(?<feature_id>\d+)[^/]*) /edit /? $}x do |feature_id|
          authenticate!
          @feature = Feature.get(feature_id) or raise Sinatra::NotFound
          @project = @feature.project
          if feature_editable?(@feature)
            haml :"feature/edit"
          else
            flash[:error] = "Other pledges have already been made to this feature. You cannot edit it now."
            redirect "/feature/#{@feature.slug}/status"
          end
        end

        app.put %r{^ /feature (?:/(?<feature_id>\d+)[^/]*) /? $}x do |feature_id|
          authenticate!
          @feature = Feature.get(feature_id) or raise Sinatra::NotFound
          @project = @feature.project
          if feature_editable?(@feature)
            attrs = params['feature'].update(project_id: @project.id)
            @feature.update(attrs)
            flash[:success] = 'Feature has been updated.'
          else
            flash[:error] = "Other pledges have already been made to this feature. You cannot edit it now."
          end
          redirect "/feature/#{@feature.slug}/status"
        end

        #--
        # TODO: Check it doesn't match another feature already entered.
        app.post '/feature' do
          authenticate!
          @project  = Project.get(params['feature']['project_id']) or raise Sinatra::NotFound
          @feature  = Feature.new(params['feature'])
          @balance  = params['pledge']['amount']

          unless params['force']
            text      = @feature.name + ' ' + @feature.detail
            @features = Search.features '@(name,detail) %s' % text, projects: [ @project.id ]
            unless @features.empty?
              # TODO Just tack this into url instead of session ? cookie sessions have 2k limit.
              #      The saved balance is used in GET /feature/<id> when the user chooses to
              #      pledge to an existing feature.
              session[:balance] = @balance
              return haml :"/feature/existing"
            end
          end

          if !params['tc']
            flash.now[:error] = 'You have not accepted the terms and conditions.'
            return haml :'/feature/new'
          end

          begin
            @balance = @project.pledge user, params['pledge']['amount'], params['feature'], client_ip
          rescue BigMoney::ParserError, TransferError => error
            flash.now[:error] = error.message
            haml :'/feature/new'
          else
            flash[:analytics] = ['pledge', 'create', @feature.id.to_s, @balance.cents_usd]
            flash[:success]   = 'Pledged %s to %s - %s.' % [@balance, @project.name, @feature.name]
            redirect url(:project, @project.slug, :pledge, {order: 'new'})
          end
        end

        #--
        # TODO: Check it doesn't match another feature already entered.
        app.post '/feature/add' do
          @project = Project.get(params['feature']['project_id']) or raise Sinatra::NotFound
          authorize! @project.user_id

          unless params['tc']
            @feature = Feature.new(params['feature'])
            flash.now[:error] = 'You have not accepted the terms and conditions.'
            return haml :'/feature/new'
          end

          @feature = @project.features.create(params['feature'].merge({user_id: user.id}))
          flash[:analytics] = ['feature', 'create', @feature.id.to_s]
          flash[:success]   = 'Created feature %s in %s' % [@feature.name, @project.name]
          redirect "/project/#{@project.slug}"
        end

        # Only reason this exists is to redirect post login on a failed POST :(
        app.get %r{^ /feature (?:/(?<feature_id>\d+)[^/]*) /pledge /? $}x do |feature_id|
          @feature = Feature.get(feature_id) or raise Sinatra::NotFound
          redirect url(:feature, '%s#pledge' % @feature.slug)
        end

        app.post %r{^ /feature (?:/(?<feature_id>\d+)) /pledge /? $}x do |feature_id|
          session[:postsignup] = { action: 'pledge', feature: feature_id, amount: params['pledge']['amount'] }

          authenticate!
          @feature = Feature.get(feature_id) or raise Sinatra::NotFound
          @project = @feature.project

          begin
            @feature.transaction do
              @balance = BigMoney.parse!(params['pledge']['amount']).exchange(:usd)
              @pledge  = user.pledge(@feature, @balance)
            end
          rescue BigMoney::ParserError, TransferError => error
            flash.now[:error] = error.message
            haml :'/feature/show'
          else
            flash[:analytics] = ['pledge', 'create', @feature.id.to_s, @balance.cents_usd]
            flash[:success]   = 'Pledged %s to %s - %s.' % [@balance, @project.name, @feature.name]
            redirect "/feature/#{@feature.slug}"
          end
        end

        app.delete %r{^ /feature (?:/(?<feature_id>\d+)) /pledge /? $}x do |feature_id|
          authenticate!
          @feature = Feature.get(feature_id) or raise Sinatra::NotFound
          @project = @feature.project
          @pledge  = @feature.pledges_by_user_id(user.id).first or raise Sinatra::NotFound
          pledges  = @feature.pledges.count
          begin
            raise 'The feature has been completed, you cannot retract your pledge now.' if @feature.state == 'complete'
            @feature.transaction { @pledge.retract! notify_owner: true, delete: true }
          rescue TransferError, RuntimeError => error
            flash.now[:error] = error.message
            haml :'/feature/show'
          else
            flash[:success] = 'Pledge retracted.'
            pledges == 1 ? redirect("/project/#{@project.slug}") : redirect("/feature/#{@feature.slug}")
          end
        end

        app.post %r{^ /feature (?:/(?<feature_id>\d+)) /comment /? $}x do |feature_id|
          authenticate!
          @feature = Feature.get(feature_id) or raise Sinatra::NotFound
          if @feature.comments.create(params[:comment].update(user: user))
            flash[:analytics] = ['comment', 'create', @feature.id.to_s]
            flash[:success]   = 'Comment created.'
          else
            flash[:error] = validation_errors @feature, 'There was an error saving your comments.'
          end
          redirect url(:feature, @feature.slug, :comment)
        end

        app.put %r{^ /feature (?:/(?<feature_id>\d+)) /acceptance (?:/(?<id>\d+))? /? $}x do |feature_id, id|
          @feature = Feature.get(feature_id) or raise Sinatra::NotFound
          @acceptance = FeatureAcceptance.get(id) or raise Sinatra::NotFound
          authorize! @acceptance.pledge.transfer.user_id

          acceptance = params['acceptance']
          if !FeatureAcceptance::STATES.include?(acceptance['state'])
            error 400, 'Bad Request'
          end

          if !@acceptance.open?
            flash[:error] = 'The acceptance time window has expired.'
          elsif @acceptance.update(acceptance)
            flash[:analytics] = ['feature', @acceptance.state, @feature.id.to_s]
            flash[:success]   = "Feature approval has been changed to: #{@acceptance.state}"
          else
            flash[:error] = 'There was an error saving feature approval changes.'
          end

          redirect "/feature/#{@feature.slug}"
        end

        app.post %r{^ /feature (?:/(?<feature_id>\d+)) /state /? $}x do |feature_id|
          @feature = Feature.get(feature_id) or raise Sinatra::NotFound
          authorize! @feature.project.user.id
          begin
            if @feature.feature_states.create(params[:state])
              flash[:success] = "Feature is now '#{params[:state][:status]}'."
            else
              flash[:error] = validation_errors @feature, 'There was an error saving the changes.'
            end
          rescue FeatureStateError => error
            flash[:error] = error.message
          ensure
            redirect url(:feature, @feature.slug, :status)
          end
        end

        app.get %r{^ /feature (?:/(?<feature_id>\d+)[^/]*) /? $}x do |feature_id|
          @feature = Feature.get(feature_id) or raise Sinatra::NotFound
          internal_redirect :get, url(:feature, feature_id, :status)
        end

        app.get %r{^ /feature (?:/(?<feature_id>\d+)[^/]*) /activity (?:\.(?<format>rss))? /? $}x do |feature_id, format|
          @feature  = Feature.get(feature_id) or raise Sinatra::NotFound

          case format
            when /rss/i
              content_type 'application/rss+xml', charset: 'utf-8'
              haml :'feature/activity.rss', layout: false
            else haml :'feature/activity'
          end
        end

        app.get %r{^ /feature (?:/(?<feature_id>\d+)[^/]*) (?:/(?<tab>status|comment))? /? $}x do |feature_id, tab|
          @tab     = tab || 'status'
          @feature = Feature.get(feature_id) or raise Sinatra::NotFound
          @project = @feature.project
          @pledge  = authenticated? ? @feature.pledges_by_user_id(user.id).first : nil
          @balance = '%.2f' % (@pledge ? -@pledge.transfer.balance.to_f : session.delete(:balance).to_f)
          haml :"/feature/show"
        end
      end
    end # Feature

    register Features
  end # Web
end # Fundry
