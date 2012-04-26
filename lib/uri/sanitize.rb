require 'uri'

module URI
  module Sanitize
    def sanitize
      self.class.sanitize(self)
    end
  end # Sanitize

  #--
  # TODO: Normalize URL encoded UTF8 to actual UTF8?
  # TODO: Param ordering? See oursignals URI::Sanitize for a more complete but slower version using addressable/uri.
  def self.sanitize uri
    sanitized = uri.to_s.strip
    sanitized = 'http://' + sanitized unless sanitized =~ %r{^\w{3,}://}
    URI.parse(sanitized)
  end
end # URI
