require 'peon'
require 'logger'
require 'em-http'
require 'forwardable'

module Job
  class Dispatcher
    # TODO temp. auth details
    AUTHORIZATION = { authorization: %w(hotshots shotshot) }

    extend Forwardable
    def_delegators :@logger, :error, :info, :warn, :fatal, :debug

    DEFAULT_OPTIONS = { host: '127.0.0.1', port: 80, timeout: 60, log_level: 0 }

    def initialize logfile=nil, options={}
      @options = DEFAULT_OPTIONS.merge(options)
      @logger  = Logger.new(logfile||$stdout, options[:log_level])
      @base    = "http://#{@options[:host]}:#{@options[:port]}"
    end

    def run &blk
      trap('INT')  { fatal 'Stopping fundry job dispatcher'; EM.stop }
      trap('TERM') { fatal 'Stopping fundry job dispatcher'; EM.stop }
      trap('TTIN') { info  'Increasing log level'; @logger.level += 1; }
      trap('TTOU') { info  'Decreasing log level'; @logger.level -= 1 if @logger.level > 0 }
      EM.run {
        begin
          info 'Starting fundry job dispatcher'
          Peon::EM.add_handler 'fundry' do |job|
            args = job.body
            args['resource'].sub!(/^\//, '')
            path = [ @base, args['resource'], args['id'], args['action'] ].join('/')
            debug "Received request for #{path}"
            params = args['params']
            http = if params.empty?
              EM::HttpRequest.new(path).get timeout: @options[:timeout], head: AUTHORIZATION
            else
              EM::HttpRequest.new(path).post timeout: @options[:timeout], head: AUTHORIZATION, body: params
            end
            http.callback {
              debug "Response status #{http.response_header.status}: #{http.response}"
              post_process_request(http, job, &blk)
            }
            http.errback  {
              debug 'Dispatch failed'
              job.release delay: 1800, &blk
            }
          end.listen
        rescue Exception => e
          error "#{e.message}\n#{e.backtrace}"
        end
      }
    end

    def post_process_request http, job, &blk
      if http.response_header.status == 200
        job.delete &blk
      elsif [ 301, 302, 303 ].include?(http.response_header.status)
        info "Redirect by worker, trying a new location #{http.response_header.location}"
        job.body['resource'] = http.response_header.location
        job.delete do
          Peon.enqueue(job.tube, job.body)
          blk.call
        end
      elsif http.response_header.status == 404
        error 'Got a 404 from worker: missing worker or resource'
        job.delete &blk
      elsif http.response_header.status == 504
        # TODO exponential backoff
        info 'Gateway timeout at worker'
        job.release delay: 1800, &blk
      elsif http.response_header.status == 503
        info 'Worker busy or unavailable'
        if http.response_header['RETRY_AFTER']
          job.release delay: http.response_header['RETRY_AFTER'], &blk
        else
          job.release delay: 1800, &blk
        end
      else
        error "Worker returned an error(#{http.response_header.status}): #{http.response}"
        job.bury 9999, &blk
      end
    end
  end
end
