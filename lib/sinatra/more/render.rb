require 'big_money'
require 'sinatra/base'
require 'uri/sanitize'

module Sinatra
  class Base
    module More
      module Render
        def partial name, options = {}
          engine = options[:engine] || :haml
          send engine, name, {layout: false}.update(options)
        end

        def mailto user
          email = user.respond_to?(:email) ? user.email : user.to_s
          URI.escape(%q{document.write('<a class="email" href="mailto:%s">%s</a>');} % [email, email], /./)
        end

        def timeago dt, engine = :haml
          dt = DateTime.parse(dt) if dt.is_a? String
          haml '%abbr.timeago{title: dt}= date', locals: {dt: dt.to_s, date: dt.strftime('%b %d, %Y')}, layout: false
        end

        def mailtime dt
          if dt.strftime("%F") == Time.now.strftime('%F')
            dt.strftime('%l:%M %P')
          else
            dt.strftime('%d %b %Y')
          end
        end

        def money money, engine = :haml
          local = authenticated? ? user.currency : :usd
          partial :'_money', locals: {local: local, money: money}, engine: engine
        end

        def sanitized_url uri
          URI.sanitize(uri).to_s
        end

        def validation_errors obj, messages = []
          html =<<-HTML
            #{messages.kind_of?(Array) ? messages.join("<br/>") : messages}
            <ul>#{obj.errors.values.flatten.map{|e| "<li>#{e}</li>" }.join("")}</ul>
          HTML
        end

        #--
        # TODO: RESTFUL routes.
        def analytics account
          # TODO WTF, why do we need a flatten here ?
          events = (flash[:analytics] || []).map {|event| "_gaq.push(#{['_trackEvent', *[event].flatten].to_json});"}
          partial :'_analytics', locals: {account: account, events: events.join("\n")}
        end
      end # Render
    end # More
    helpers More::Render
  end # Base
end # Sinatra
