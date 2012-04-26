module Fundry
  class Web
    module Admin
      def self.registered app
        app.get '/admin' do
          authenticate!
          user.admin? or raise Sinatra::NotFound
          haml :"admin/show"
        end

        app.get %r{^ /admin /verification /(?<group>(?:all|confirm|recent)) $}x do |group|
          authenticate!
          user.admin? or raise Sinatra::NotFound
          ordering = [:created_at.desc, :updated_at.desc]
          recent   = Time.now-172800..Time.now  # last 2 days
          @projects = case group
            when 'all'
              Project.all(verified: false, order: ordering)
            when 'confirm'
              Project.awaiting_confirmation(order: ordering)
            when 'recent'
              Project.all(verified: false, verifications: {rank: 0, created_at: recent}, order: ordering)
          end
          haml :"admin/verification"
        end

        app.post %r{^ /admin /project /(?<action>(approve|reject)) /(?<id>\d+) $}x do |action, id|
          authenticate!
          user.admin? or raise Sinatra::NotFound
          project = Project.get(id) or raise Sinatra::NotFound

          case action
            when 'approve'
              project.verifications.create(verified: true, message: "manually verified by #{user.name}") or
              halt 500, validation_errors(project)
            when 'reject'
              project.verifications.create(verified: false, message: params[:message], rank: -1) or
              halt 500, validation_errors(project)
          end
          'ok'
        end

        app.post %r{^ /admin /pretend $}x do
          authenticate!
          user.admin? or raise Sinatra::NotAuthorized
          user = User.first(username: params[:profile]) or raise Sinatra::NotFound

          login_as! user
          redirect '/profile'
        end
      end
    end # Admin

    register Admin
  end # Web
end # Fundry
