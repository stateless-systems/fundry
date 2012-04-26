module Fundry
  class Web
    module General

      SEARCH_OPTIONS = { limit: 5, sort_mode: :extended, sort_by: '@relevance DESC, score DESC, @id ASC' }

      module Helpers
        def tweet_url title
          title ||= 'fundry.com'
          safe_title = URI.escape(title).gsub(/'/, '').gsub(/%20/, '+')
          safe_url   = URI.escape(absolute_insecure_url(request.url))
          'http://www.twitter.com/share?count=none&url=%s&text=%s&via=fundrydotcom' % [ safe_url, safe_title ]
        end
      end

      def self.registered app
        app.helpers Helpers

        app.get '/' do
          redirect '/project', 301
        end

        app.get '/activity.rss' do
          content_type 'application/rss+xml', charset: 'utf-8'
          haml :'activity.rss', layout: false
        end

        app.get '/pledge' do
          @tab     = 'pledge'
          @pledges = params[:order] == 'new' ? Fundry::Pledge.all(order: [:created_at.desc]) : Fundry::Pledge.top
          haml :pledge
        end

        app.get '/donation' do
          @tab       = 'donation'
          @donations = params[:order] == 'new' ? Fundry::Donation.all(order: [:created_at.desc]) : Fundry::Donation.top
          haml :donation
        end

        app.get '/comment' do
          @tab      = 'comment'
          @comments = Fundry::Comment.all(order: [:created_at.desc])
          haml :comment
        end

        app.get '/search/?' do
          no_cache
          if params[:query] && params[:query].length > 0
            @projects = Search.projects params[:query], SEARCH_OPTIONS
            @features = Search.features params[:query], limit: 5
          else
            @projects = @features = []
          end
          haml :search
        end

        app.get '/terms' do
          haml :terms
        end

        app.get '/markdown-modal' do
          haml :_markdown_reference, layout: false
        end

        app.get '/terms-modal' do
          haml :_terms, layout: false
        end

        app.get '/privacy' do
          haml :privacy
        end

        app.get '/disclaimer' do
          haml :disclaimer
        end

        app.get '/about' do
          haml :about
        end

        app.get '/faq' do
          haml :faq
        end

        app.get '/markdown' do
          haml :markdown
        end
      end
    end # General

    register General
  end # Web
end # Fundry
