require 'katamari-flash'

module Sinatra
  class Base
    module More
      module Request
        DEFAULT_PORTS = [ 80, 443 ]
        def id
          route = request.path.gsub(%r{^/|/$}, '').split('/').reject{|c| c =~ /^\d+/}.join('_')
          'path_' + (route.empty? ? 'root' : route)
        end

        def classes
          request.path.gsub(%r{^/|/$}, '').split('/').reject{|c| c =~ /^\d+/}.join(' ')
        end

        #--
        # TODO: Encoding.
        def url *path
          params = path[-1].respond_to?(:to_hash) ? path.delete_at(-1).to_hash : {}
          params = params.empty? ? '' : '?' + URI.escape(params.map{|*a| a.join('=')}.join('&')).to_s
          '/' + path.compact.map(&:to_s).join('/') + params
        end

        def absolute_url *path
          port = DEFAULT_PORTS.include?(request.port.to_i) ? '' : ':' + request.port.to_s
          request.scheme + '://' + request.host + port + url(*path)
        end

        def internal_redirect method, path, stash={}
          # KatamariFlash keeps appending to the :success and :error flash vars
          # and stringifies them into a <br/> seperated string.
          session[:__FLASH__]   = KatamariFlash.create session[:__FLASH__]
          env['REQUEST_METHOD'] = method.to_s.upcase
          env['REQUEST_PATH']   = path
          env['PATH_INFO']      = path

          params.merge! stash

          # code below stolen from Sinatra::Base
          invoke { dispatch! }
          invoke { error_block!(response.status) }

          status, header, body = @response.finish

          if @env['REQUEST_METHOD'] == 'HEAD'
            body = []
            header.delete('Content-Length') if header['Content-Length'] == '0'
          end

          halt status, header, body
        end

        def booleanize! *args, stash
          if args.length == 1
            top = args.shift
            stash[top] = !!stash[top]
            stash
          else
            top = args.shift
            stash[top] = booleanize! *args, stash[top] || {}
          end
          stash
        end
      end # Request
    end # More
    helpers More::Request
  end # Base
end # Sinatra
