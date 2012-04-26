require 'yajl'
require 'timeout'
require 'forwardable'
require 'beanstalk-client'

require_relative 'peon/em'

module Peon
  SERVER = (ENV["BEANSTALKD_SERVER"] || "127.0.0.1:11300").split(":")

  class << self

    extend Forwardable
    def_delegators :beanstalk,
      *%w{use watch ignore reserve peek_ready peek_delayed peek_buried list delete touch bury kick pause release put}

    def enqueue tube, data
      beanstalk.use(tube)
      beanstalk.put(Yajl.dump({tube: tube, data: data}))
    end

    def flush *tubes
      tubes = tubes.empty? ? beanstalk.list_tubes.values.flatten : tubes.uniq

      tubes.each {|tube| watch(tube) }
      ignore('default') unless tubes.empty? or tubes.include?('default')

      beanstalk.kick 4294967295
      beanstalk.kick 4294967295
      remaining = tubes.inject(0) {|a, tube| a + beanstalk.stats_tube(tube)['current-jobs-ready'] }
      while remaining > 0
        job = dequeue
        job.delete if job
        remaining = tubes.inject(0) {|a, tube| a + beanstalk.stats_tube(tube)['current-jobs-ready'] }
      end
    end

    def dequeue secs=0.25, tube='fundry'
      beanstalk.watch(tube)
      return timeout(secs) { beanstalk.reserve } rescue nil
    end

    def beanstalk
      @@beanstalk ||= ::Beanstalk::Pool.new([SERVER.join(":")])
    end

    def stats type=nil, id=nil
      case type
        when :job  then beanstalk.job_stats(id)
        when :tube then beanstalk.stats_tube(id)
        else beanstalk.stats
      end
    end

  end # self
end # Peon

module Beanstalk
  class Connection
    def kick bound
      interact("kick #{bound}\r\n", %w(KICKED))
    end
  end

  class Pool
    def kick bound
      send_to_all_conns(:kick, bound)
    end
  end
end
