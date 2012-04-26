require 'fileutils'
module Fundry
  module Cli
    module Database

      def self.check_slave
        Monitor.check_slave
      end

      module Monitor
        def self.log_position string
          position = string.split('/')
          Integer('0x' + position.first) * 0xffffffff + Integer('0x' + position.last)
        end

        def self.check_slave
          master = DataMapper.repository.adapter
          slave  = DataMapper.setup(:slave,
            host:     'replicant',
            user:     'monitor',
            password: 'm0nit3r',
            adapter:  :postgres,
            database: 'fundry',
            encoding: 'UTF-8'
          )

          master_xlog_position = log_position master.select('select pg_current_xlog_location()').first
          slave_xlog_received  = log_position slave.select('select pg_last_xlog_receive_location()').first
          slave_xlog_replay    = log_position slave.select('select pg_last_xlog_replay_location()').first

          DataObjects::Pooling.pools.map(&:dispose)

          raise "Master/Slave delay > 160" if (master_xlog_position - slave_xlog_received) > 160
        end
      end # Monitor

    end # Database
  end # Cli
end # Fundry
