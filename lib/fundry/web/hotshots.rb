#!/usr/bin/ruby

require 'pathname'
libdir = Pathname.new(__FILE__).dirname + '..' + '..'

require libdir + 'fundry'
require libdir + 'sinatra/more'

require 'async-rack'
require 'em-http'
require 'fileutils'
require 'uri/sanitize'

# All hotshots redirects.
#
# 1. To keep ssl happy.
# 2. To hide hotshots so others dont misuse it.

module Fundry
  module Web
    class Hotshots < Sinatra::Base

      # root app directory.
      ROOT         = Pathname.new(__FILE__).dirname + '..' + '..' + '..'
      # content type.
      CONTENT_TYPE = 'image/jpeg'
      # RFC1123 format.
      RFC1123_TIME = '%a, %d %b %Y %T GMT'
      # forward slash is unsafe too.
      UNSAFE       = %r{[^-_.!~*'()a-zA-Z\d;?:@&=+$,\[\]]}

      # provider
      PROVIDER     = 'screenshots.thewall.com'


      disable :raise_errors, :show_exceptions, :static, :dump_errors
      enable  :logging

      get '/shots/:id/favicon' do |id|
        project = Project.get(id) or raise Sinatra::NotFound
        path    = ROOT + "public/shots/#{id}"
        url     = project.web.sub(%r{([^:/])/.*$}) { $1 } + '/favicon.ico'

        begin
          url  = URI.sanitize(url).to_s
          http = EM::HttpRequest.new(url).get timeout: 5, redirects: 2
          http.callback do
            if http.response_header.status == 200 && http.response_header.content_length.to_i > 0
              FileUtils.mkpath(path) unless File.exists?(path)
              filename = path + "favicon.ico"
              File.open(filename, 'w') {|fh| fh.write(http.response) } rescue nil
              headers = {}
              http.response_header.each do |k,v|
                headers[k.split(/_/).map(&:capitalize).join('-')] = v
              end
              env["async.callback"].call [ 200, headers, [ http.response ] ]
            else
              headers = {
                'Expires'          => (Time.now.utc + 3600).strftime(RFC1123_TIME),
                'Cache-Control'    => 'max-age=3600',
                'X-Accel-Redirect' => '/favicon.ico'
              }
              env["async.callback"].call [ 200, headers, [] ]
            end
          end

          http.errback do
            puts 'Unable to fetch image: ' + url
            env["async.callback"].call [ 404, {}, [ 'error. image not found' ] ]
          end
        rescue Exception => e
          puts e.message
          env["async.callback"].call [ 404, {}, [ 'error. image not found' ] ]
        end

        throw :async
      end

      get '/shots/:id/:size' do |id, size|
        project = Project.get(id) or raise Sinatra::NotFound
        url     = "http://#{PROVIDER}/shot?url=%s&size=%s" % [ URI.escape(project.web, UNSAFE), size ]
        path    = ROOT + "public/shots/#{id}"

        begin
          http = EM::HttpRequest.new(url).get timeout: 5, redirects: 0, head: { authorization: %w(hotshots shotshot) }

          # TODO handle 500s, 404s and 410s differently.
          http.callback do
            headers = {}
            if http.response_header.status == 200
              FileUtils.mkpath(path) unless File.exists?(path)
              filename = path + "#{size}.jpg"
              cached = File.open(filename, 'w') {|fh| fh.write(http.response) } rescue nil
              env['rack.logger'].puts "Unable to cache #{filename}" unless cached

              http.response_header.each do |k,v|
                headers[k.split(/_/).map(&:capitalize).join('-')] = v
              end
              env["async.callback"].call [ 200, headers, [ http.response ] ]
            else
              headers = {
                'Expires'          => (Time.now.utc + 3600).strftime(RFC1123_TIME),
                'Cache-Control'    => 'max-age=3600',
                'X-Accel-Redirect' => '/art/images/defaultScreenshot.png'
              }
              env["async.callback"].call [ 200, headers, [] ]
            end
          end

          http.errback do
            puts 'Unable to fetch image: ' + url
            env["async.callback"].call [ 404, {}, [ 'error. image not found' ] ]
          end
        rescue Exception => e
          puts e.message
          env["async.callback"].call [ 404, {}, [ 'error. image not found' ] ]
        end

        throw :async
      end

      error Sinatra::NotFound do
        '404 image not found'
      end

    end # Hotshots
  end # Web
end # Fundry
