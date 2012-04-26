require 'rack'
module Rack
  class Request
    def scheme
      @env['HTTP_X_FORWARDED_PROTO'] || @env['X-Forwarded-Proto'] || @env['rack.url_scheme']
    end
  end
end
