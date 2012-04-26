require 'rack'
require 'rack/utils'

module Rack
  class Encoder
    ENCODING_UTF8         = Encoding.find 'UTF-8'
    ENCODING_ISO8859_1    = Encoding.find 'ISO8859-1'
    ENCODING_ASCII8BIT    = Encoding.find 'ASCII-8BIT'

    CONTENT_URLENCODED    = %r{application/x-www-form-urlencoded}
    POST_REQUEST          = %r{(?:POST|PUT)}i

    def initialize app
      @app = app
    end

    def call env
      method            = env['REQUEST_METHOD'] || 'GET'
      content_type      = env['CONTENT_TYPE']   || ''
      env['rack.input'] = utf8_datastream(env) if method.match(POST_REQUEST) && content_type.match(CONTENT_URLENCODED)
      @app.call(env)
    end

    # Since there is no fucking consensus on identifying charset in POST requests, we need to
    #
    # 1. Check if charset is specified in Content-Type header
    # 2. or we sent across a funny snowman in a hidden _utf8 parameter
    # 3. check for charset variable which some sick java apps (paypal) send through
    # 4. use the usual latin1 encoding if all else fails
    def utf8_datastream env
      io, content_type = env['rack.input'], env['CONTENT_TYPE']
      if io
        data = io.read
        return StringIO.new(data) unless data && data.length > 0
        case
          when (content_type || '').match(/\s*;\s*charset\s*=\s*(.*?)\s*(?:;|$)/)
            encoding = Encoding.find($1.gsub(/_/, '-')) rescue ENCODING_ISO8859_1
          when data && data.match(/_utf8=%E2%98%83/)
            encoding = 'UTF-8'
          when data && data.match(/charset=([-\w]+)/)
            encoding = Encoding.find($1.gsub(/_/, '-')) rescue ENCODING_ISO8859_1
          else
            encoding = ENCODING_ISO8859_1
        end
        StringIO.new(data.force_encoding(encoding))
      end
    end
  end

  # Override the default unescape method to preserve encoding.
  module Utils
    def self.unescape(string)
      encoding = string.encoding == Encoder::ENCODING_ASCII8BIT ? Encoder::ENCODING_ISO8859_1 : string.encoding
      string.tr('+', ' ')
            .gsub(/((?:%[0-9a-fA-F]{2})+)/n){ [$1.delete('%')].pack('H*') }
            .force_encoding(encoding)
            .encode!(Encoder::ENCODING_UTF8)
    end
  end
end
