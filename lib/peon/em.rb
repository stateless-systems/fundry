require 'yajl'
require 'em-jack'
require 'forwardable'

module Peon
  class EM
    # I've not used DelegateClass here to avoid method_missing madness.
    extend Forwardable
    def_delegators :jack,
      *%w{use watch ignore reserve peek stats list delete touch bury kick pause release each_job}

    # Adds a job handler
    #
    # ==== Parameters
    # tube<String>    A queue name
    # callback<Proc>  A callback that handles the request for a job
    #
    # ==== Returns
    # Peon::EM
    #
    # ==== Raises
    # ArgumentError
    def add_handler tube, &callback
      raise ArgumentError, "missing +callback+" if callback.nil?
      tube                = tube.to_s
      handlers[tube]      = callback
      self
    end

    # Listens to beanstalk server on all tubes and dispatches jobs to approproate handlers.
    #
    # ==== Raises
    # Exception
    def listen
      Thread.new { EventMachine.run } unless EventMachine.reactor_running?
      jack.each_job(2) do |job|
        job = Job.new(job.conn, job.jobid, job.body)
        EventMachine.defer proc { process(job) }, proc {|res| raise(res) if res.kind_of?(Exception) }
      end
    end

    def put &blk
      jack.put(Yajl.dump({tube: tube, data: data}), &blk)
    end

    class << self
      def add_handler *args, &blk
        self.new.add_handler(*args, &blk)
      end
      def listen queue='default', &blk
        add_handler(queue, &blk).listen
      end
    end

    class Job < EMJack::Job
      attr_accessor :tube
      alias_method :id, :jobid

      def initialize conn, id, body
        @jobid = id
        @conn  = conn
        @body  = Yajl.load(body)
        @tube  = @body.delete("tube") || "default"
        @body  = @body.delete("data")
      end
    end # Job

    def reconnect!
      @jack = EMJack::Connection.new(:host => SERVER[0], :port => SERVER[1].to_i)
      tubes = handlers.keys.map(&:to_s)
      tubes.each {|tube| watch(tube) }
      ignore('default') unless tubes.include?('default')
      @jack
    end

    private

    def handlers
      @handlers ||= {}
    end

    def process job
      begin
        if handler = @handlers[job.tube]
          handler.call(job)
        else
          job.release delay: 1800
        end
      rescue Exception => error
        error
      end
    end

    def jack
      @jack ||= reconnect!
    end
  end # EM
end # Peon
