# All project related request handling.
module Fundry
  class Web
    module Projects
      def self.registered app
        app.get '/project' do
          @tab      = 'project'
          @projects = params[:order] == 'new' ?
            Project.all(verified: true, order: [:created_at.desc]) : Project.top
          haml :project
        end

        app.get '/project/new' do
          session[:postsignup] = { action: 'project' }
          authenticate!
          @project = user.projects.new
          haml :'project/new'
        end

        app.post '/project' do
          authenticate!
          @project = user.projects.create(params['project'])
          if @project.saved?
            flash[:analytics] = ['project', 'create', @project.id.to_s]
            flash[:success]   = 'Project created.'
            redirect url(:project, @project.slug)
          else
            flash.now[:error] = validation_errors @project, 'There was an error saving the changes.'
            haml :'/project/new'
          end
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /? $}x do |project_id|
          @project  = Project.get(project_id) or raise Sinatra::NotFound
          internal_redirect :get, url(:project, project_id, :feature)
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /feature /? $}x do |project_id|
          @project  = Project.get(project_id) or raise Sinatra::NotFound
          @features = @project.features.all(order: [:created_at.desc])
          haml :"/project/feature"
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /pledge /? $}x do |project_id|
          @project  = Project.get(project_id) or raise Sinatra::NotFound
          @pledges  = @project.features.pledges.all(order: [:created_at.desc])
          haml :"/project/pledge"
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /donation /? $}x do |project_id|
          @project   = Project.get(project_id) or raise Sinatra::NotFound
          @donations = @project.donations.all(order: [:created_at.desc])
          haml :"/project/donation"
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /comment /? $}x do |project_id|
          @project  = Project.get(project_id) or raise Sinatra::NotFound
          @comments = @project.features.comments.all(order: [:created_at.desc])
          haml :"/project/comment"
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /(?<ad>widget|button) /? $}x do |project_id, ad|
          @project = Project.get(project_id) or raise Sinatra::NotFound
          haml :"/project/#{ad}", layout: false, escape_html: ad == 'button'
        end

        app.put %r{^ /project (?:/(?<project_id>\d+)) /verify /? $}x do |project_id|
          authenticate!
          @project = user.projects.get(project_id) or raise Sinatra::NotFound
          begin
            @project.queue_verification absolute_url(:project, @project.slug)
            flash[:success] = 'Queued Project for verification.'
          rescue Project::VerificationError => error
            flash[:error] = error.message
          end
          redirect url(:project, @project.slug)
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /edit /? $}x do |project_id|
          authenticate!
          @project = user.projects.get(project_id) or raise Sinatra::NotFound
          haml :'/project/edit'
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /report /? $}x do |project_id|
          authenticate!
          project = Project.get(project_id) or raise Sinatra::NotFound
          if project.abuse_reports(user_id: user.id).first
            flash[:error] = 'You have already reported this project for abuse.'
          else
            project.abuse_reports.create(user_id: user.id)
            flash[:success] = 'Thanks, your abuse report was registered. We will look into it soon.'
          end
          redirect url(:project, project.slug)
        end

        app.put %r{^ /project (?:/(?<project_id>\d+)) /? $}x do |project_id|
          authenticate!
          @project = user.projects.get(project_id) or raise Sinatra::NotFound

          # remove cached project screenshots.
          if @project.web != params['project']['web']
            FileUtils.rm_rf(Fundry.root + "/public/shots/#{project_id}")
          end

          if @project.update(params['project'])
            flash[:success] = 'Project updated.'
            redirect url(:project, @project.slug)
          else
            flash.now[:error] = validation_errors @project, 'There was an error saving the changes.'
            haml :'/project/edit'
          end
        end

        app.delete %r{^ /project (?:/(?<project_id>\d+)) /? $}x do |project_id|
          authenticate!
          @project = user.projects.get(project_id) or raise Sinatra::NotFound
          @project.destroy
          redirect '/profile'
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /feature/new /? $}x do |project_id|
          @project = Project.get(project_id) or raise Sinatra::NotFound
          unless @project.active?
            flash[:error] =<<-ERROR
              The project has been disabled.
              Donations and Pledges cannot be made at this time.
            ERROR
            redirect url(:project, @project.slug)
          end

          if @project.user.suspended?
            flash[:error] =<<-ERROR
              The project owner account has been temporarily suspended.
              Donations and Pledges cannot be made at this time.
            ERROR
            redirect url(:project, @project.slug)
          end

          session[:postsignup] = { action: 'pledge', project: project_id }
          authenticate!

          @feature = Feature.new(project: @project)
          @balance = '0.50'
          haml :'/feature/new'
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /donation/new /? $}x do |project_id|
          @project = Project.get(project_id) or raise Sinatra::NotFound
          unless @project.active?
            flash[:error] =<<-ERROR
              The project has been disabled.
              Donations and Pledges cannot be made at this time.
            ERROR
            redirect url(:project, @project.slug)
          end
          if @project.user.suspended?
            flash[:error] =<<-ERROR
              The project owner account has been temporarily suspended.
              Donations and Pledges cannot be made at this time.
            ERROR
            redirect url(:project, @project.slug)
          end

          session[:postsignup] = { action: 'donation', project: project_id }
          authenticate!

          @donation = Donation.new(project: @project)
          haml :'/donation/new'
        end

        app.get %r{^ /project (?:/(?<project_id>\d+)[^/]*) /activity (?:\.(?<format>rss))? /? $}x do |project_id, format|
          @project  = Project.get(project_id) or raise Sinatra::NotFound

          case format
            when /rss/i
              content_type 'application/rss+xml', charset: 'utf-8'
              haml :'project/activity.rss', layout: false
            else haml :'project/activity'
          end
        end
      end
    end # Projects

    register Projects
  end # Web
end # Fundry
