require 'nokogiri'
require 'curb'

module Fundry
  class Project
    class VerificationError < StandardError; end

    # TODO split queueing and actual verification stuff.
    # TODO make verification async run on a separate thin + rack-async + em-synchrony stack ?
    module VerificationQueue
      VERIFY_NS     = "pr:v"
      VERIFY_TTL    = 1800
      VERIFY_TRIES  = 5

      def cache
        @@cache ||= Moneta::Redis2.new(server: 'localhost', default_ttl: 86_400)
      end

      # Queues a project for verification and checks if the given URI appears either in script CDATA.
      #
      # ==== Paramaters
      # uri<String>:: Widget URI that must appear in script CDATA somewhere on the projects web address.
      def queue_verification uri
        raise VerificationError, "+project+ already queued for verification" if queued_verification?
        cache.store(verification_key, 1, expires_in: VERIFY_TTL)
        schedule_work :verify, { uri: uri }
      end

      def queued_verification?
        cache.key? verification_key
      end

      def needs_verification_reminder?
        now = DateTime.now
        !verified  && user.want_reminders? && (created_at.between?(now-2, now-1) || created_at < now-7)
      end

      def verification_timeout?
        tries = cache[verification_key].to_i
        if tries.nil? or tries > VERIFY_TRIES
          true
        else
          cache.store(verification_key, tries+1, expires_in: VERIFY_TTL)
          false
        end
      end

      def verification_key
        "#{VERIFY_NS}:#{self.id}"
      end
    end # VerificationQueue

    module Verification
      PARSER_OPTIONS = Nokogiri::XML::ParseOptions::NOENT | Nokogiri::XML::ParseOptions::RECOVER
      USER_AGENT     = 'fundry-verification/0.1 +fundry.com'
      TIMEOUT        = 10

      # Verify the given URI appears either in script CDATA.
      #
      # ==== Paramaters
      # uri<String>:: Widget URI that must appear in script CDATA somewhere on the projects web address.
      #--
      def verify! uri
        verify_fail('Project has no web address.') if web.nil? || web.empty?

        sanitized = URI.sanitize(web.to_s)

        begin
          response = Curl::Easy.perform(sanitized.to_s) do |c|
            c.headers['User-Agent'] = USER_AGENT
            c.connect_timeout = TIMEOUT
            c.follow_location = true
          end
        rescue Curl::Err::HostResolutionError, Curl::Err::ConnectionFailedError
          verify_fail("Unable to resolve host at #{sanitized}")
        end

        status = response.response_code

        # TODO allow redirection across same domain using vendor/effective_tld_names.dat
        if status == 200 && sanitized.host != URI.parse(response.last_effective_url).host
          verify_fail("Redirection across hosts #{sanitized} -> #{response.last_effective_url}")
        end

        if status == 200
          uri  = URI.parse(uri) unless uri.kind_of?(URI)
          html = Nokogiri::HTML.parse(response.body_str, nil, nil, PARSER_OPTIONS)

          rank = 0
          rank += 10 if verify_anchor_exists(uri, html)
          rank += 50 if verify_widget_exists(uri, html)
          if rank > 0
            verifications.create(message: 'project link/widget found.', rank: rank)
          else
            verify_fail("Project doesn't link to '#{uri}'.")
          end
        else
          verify_fail("Got a response code of #{response.response_code}")
        end
      end

      def verify_anchor_exists uri, html
        secure_uri   = (uri.scheme = 'https') && uri.to_s
        insecure_uri = (uri.scheme = 'http')  && uri.to_s

        html.xpath('//a').find{|l| l['href'] == secure_uri || l['href'] == insecure_uri }
      end

      def verify_widget_exists uri, html
        secure_uri   = (uri.scheme = 'https') && uri.to_s
        insecure_uri = (uri.scheme = 'http')  && uri.to_s
        expect       = Regexp.new("#{secure_uri}|#{insecure_uri}")

        html.xpath('//script').find{|s| s.inner_html =~ expect}
      end

      def verify_fail message
        verifications.create(verified: false, message: message)
        raise VerificationError, message
      end
    end # Verification

    include Verification
    include VerificationQueue
  end # Project
end # Fundry
