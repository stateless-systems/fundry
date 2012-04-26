require 'rack'
require 'thin'
require 'timeout'

module Rack
  module Test
    class App

      # Shane's attempt to run a Rack app server instance in the same process as the a 'work' block. Came about because
      # you can't see an unsaved DB transaction inside the Rack app if it happens in another process.
      #
      # ==== Example
      #
      #   require 'minitest/spec'
      #   require 'rack/test/app'
      #   require 'open-uri'
      #
      #   describe 'MyApp' do
      #     it 'must respond ok' do
      #       Rack::Test::App.run lambda{|env| [200, {'Content-Type' => 'text/plain'}, ['ok']]} do
      #         assert open('http://localhost:3000').read =~ /ok/
      #       end
      #     end
      #   end
      #
      # ==== Paramaters
      # app<Object>::   Rack 'app' responding to call.
      # options<Hash>:: Options include host: and port:.
      # work<Proc>::    Connect and work with the 'app'. When this block exits the app will stop.
      def self.run app, options = {}, &work
        host   = options[:host]    ||= '0.0.0.0'
        port   = options[:port]    ||= '3000'
        ts     = options[:timeout] ||= 5
        socket = options[:socket]

        timeout(ts) do
          @error = nil
          EM.run do
            Thin::Logging.silent = true
            if socket
              Thin::Server.start app, socket
              sleep 0.1
            else
              Thin::Server.start app, host, port.to_i
              TCPSocket.new host, port
            end
            EM.defer proc { begin; work.call; rescue Exception => e; @error = e; end }, proc {|r| EM.stop }
          end
          raise @error if @error
        end
      end
    end # App
  end # Test
end # Rack
