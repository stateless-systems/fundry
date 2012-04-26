# encoding: utf-8
root = File.join(File.dirname(__FILE__), '..')

# Bundler.
require File.join(root, 'gems', 'environment')
$:.unshift File.join(root, 'lib')

# NOTE I had to explicitly require json_pure and then override it with yajl.
require 'json'
require 'yajl/json_gem'

# DataMapper.
require 'dm-aggregates'
require 'dm-core'
require 'dm-constraints'
require 'dm-is-tree'
require 'dm-money'
require 'dm-types'
require 'dm-timestamps'
require 'dm-validations'
require 'dm-transactions'

# Extra DataMapper hacks and stuff.
require 'dm/transactions'
require 'dm/sql_collection'
require 'dm/locking'

# Queueable resource for jamming any resource into a job queue for some work.
require 'dm/queueable'

# DataMapper::Logger.new($stderr, :debug) # XXX: Debugging.
pg = DataMapper.setup(:default, adapter: :postgres, database: 'fundry', encoding: 'UTF-8')
pg.extend DataMapper::NestedTransactions
pg.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule

# Money.
require 'big_money'
require 'big_money/constants'
require 'big_money/exchange/yahoo'
require 'big_money/parser'

require 'moneta'
require 'moneta/redis2'

BigMoney::Exchange.cache = Moneta::Redis2.new(server: 'localhost', default_ttl: 86_400)

# Business logic.
require 'fundry/abuse_report'
require 'fundry/comment'
require 'fundry/donation'
require 'fundry/email'
require 'fundry/event'
require 'fundry/feature'
require 'fundry/feature_state'
require 'fundry/feature_acceptance'
require 'fundry/pledge'
require 'fundry/project'
require 'fundry/role'
require 'fundry/statistics'
require 'fundry/subscription'
require 'fundry/user'
require 'fundry/verification'

module Fundry
  def self.root
    File.expand_path(File.join(File.dirname(__FILE__), '..'))
  end
end # Fundry

