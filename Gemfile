# vim: syntax=ruby
bundle_path 'gems'
disable_rubygems
disable_system_gems

# Web.
gem 'rack', '1.2.1'
gem 'haml'
gem 'rdiscount'
gem 'sanitize'

# Branch has improved 1.9 named capture routing.
gem 'sinatra', '1.0' # http://github.com/shanna/sinatra/tree/named_capture_routing

gem 'sinatra-auth'
gem 'rack-flash'
gem 'yajl-ruby', '0.7.6'

# Fork removes dependency on packr and rainpress
gem 'sinatra-bundles', '0.4.0' # http://github.com/deepfryed/sinatra-bundles.

# Fork has massive pure Ruby IDNA junk removed.
gem 'addressable', '2.1.2' # http://github.com/deepfryed/addressable

# Persistence.
do_version = '>= 0.10.1'
gem 'data_objects', do_version
gem 'do_postgres',  do_version

dm_version = '~> 1.0'
gem 'dm-aggregates',       dm_version
gem 'dm-core',             dm_version
gem 'dm-constraints',      dm_version
gem 'dm-is-tree',          dm_version
gem 'dm-postgres-adapter', dm_version
gem 'dm-serializer',       dm_version
gem 'dm-timestamps',       dm_version
gem 'dm-types',            dm_version
gem 'dm-validations',      dm_version
gem 'dm-transactions',     dm_version

# Queueing.
gem 'eventmachine', '0.12.10'
gem 'beanstalk-client', '1.0.2'
gem 'em-jack', '0.1.1'
gem 'em-http-request', '0.2.14'

# Hotshots proxy.
gem 'async-rack',  '0.4.0.1'
gem 'thin',        '1.2.7'

# Mailer.
gem 'pony-express', '0.7.0'
gem 'nokogiri', '1.4.2'

# Other.
gem 'dm-money'
gem 'moneta', '0.6.0'
gem 'riddle'
gem 'curb'
gem 'uuid', '0.1.0'
gem 'fastcaptcha', '0.2.4'
gem 'redis'

only :development do
  gem 'racksh'
  gem 'unicorn'
end

only :test do
  gem 'ansi'
  gem 'mechanize', '1.0.0'
end
