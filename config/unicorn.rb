# vim: filetype=ruby

require ::File.dirname(__FILE__) + '/unicorn_settings'

env     = ENV['RACK_ENV'] || 'development'
options = UNICORN_SETTINGS[env.to_sym]

timeout 30
pid options[:pidfile]
worker_processes options[:workers]

listen options[:socket], backlog: options[:backlog]
listen options[:port], tcp_nopush: true if options.key?(:port)

stderr_path options[:stderr] if options[:stderr]
stdout_path options[:stdout] if options[:stdout]

preload_app true

# avoid shuffle segfaults in older version of ruby 1.9.1 or 1.9.2.
after_fork do |server, worker|
  Kernel.rand
end
