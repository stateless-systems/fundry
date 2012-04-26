require 'uri'
require 'curb'

# Paypal NVP
class Paypal
  def initialize url, user, password, signature, version = '56.0'
    @url         = URI.parse(url)
    @credentials = {user: user, pwd: password, signature: signature, version: version}
  end

  #--
  # TODO: Error handling?
  # TODO: Response API instead of raw hash?
  def perform data
    uri       = @url.dup
    uri.query = data.merge(@credentials).map{|k, v| "#{k.to_s.upcase}=#{URI.escape(v.to_s)}"}.join('&')
    curl      = Curl::Easy.perform(uri.to_s) do |easy|
      easy.ssl_verify_host = false
      easy.ssl_verify_peer = false
    end

    curl.body_str.split('&').inject({}) do |acc, element|
      a = element.split('=')
      acc[a[0].downcase.to_sym] = URI.decode(a[1].to_s) if a.size == 2
      acc
    end
  end
end # Paypal

