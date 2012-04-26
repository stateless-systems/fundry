require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'fundry'))
Bundler.require_env(:test)

# DataMapper::Logger.new($stdout, :debug)
pg = DataMapper.setup(:default, adapter: :postgres, database: 'fundry_test')
pg.extend DataMapper::NestedTransactions
pg.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule

require 'fundry/migrations'
Fundry.auto_migrate!

require 'minitest/unit'
require 'minitest/spec'
require 'minitest/pretty'

ENV['RACK_ENV'] = 'test'

MiniTest::Unit.autorun

# NOTE allow http://localhost:8080 type urls for testing
class Fundry::Project
  def validate_web
    sanitized = URI.sanitize(web.to_s)
    sanitized.is_a?(URI::HTTP) || [false, 'Must be http(s) scheme.']
    [true, nil]
  rescue => error
    [false, error.message]
  end
end

class MiniTest::Unit::TestCase
  # TODO: Move to mixin.
  def new_user options = {}
    @new_user_count ||= 0
    @new_user_count += 1
    balance = options.delete(:balance)
    user    = Fundry::User.create({
      username: "fred#{@new_user_count}",
      name:     'Fred Nerk',
      email:    "fred#{@new_user_count}@localhost",
      password: 'fred'
    }.update(options))
    Fundry::Payment.create(user_id: user.id, balance: balance).complete! if balance
    Fundry::User.get(user.id)
  end

  def new_project options
    Fundry::Project.create({summary: 'blah blah', detail: 'blah blah'}.merge(options))
  end

  def setup
    repository(:default) do
      transaction = DataMapper::Transaction.new(repository)
      transaction.begin
      repository.adapter.push_transaction(transaction)
    end
  end

  def teardown
    repository(:default) do
      while repository.adapter.current_transaction
        repository.adapter.pop_transaction.rollback
      end
    end
  end
end

# Make sure to call setup & teardown.
class MiniTest::Spec
  def self.before(type = :each, &block)
    raise "unsupported before type: #{type}" unless type == :each
    define_method :setup do
      super()
      self.instance_eval &block
    end
  end
  def self.after(type = :each, &block)
    raise "unsupported after type: #{type}" unless type == :each
    define_method :teardown do
      super()
      self.instance_eval &block
    end
  end
end
