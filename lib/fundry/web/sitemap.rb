module Fundry
  class Web
    module Sitemap
      URLS = %w(about comment donation faq feature pledge project terms)
      def self.registered app
        app.get '/sitemap.xml' do
          content_type :xml
          expires 86400
          @urls = URLS.map {|url| absolute_insecure_url(url) }
          haml :"sitemap/xml", layout: false
        end
      end
    end # Sitemap

    register Sitemap
  end # Web
end # Fundry
