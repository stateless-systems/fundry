# http://gist.github.com/323511
# Add pessmistic locking support. Make sure you're inside a transaction.
#   resource = MyResource.get(24)
#   resource.lock! # write lock (FOR UPDATE)
#
# TODO:
#   resource = MyResource.get_with_lock!(:write, 24)
#   resource = MyResource.get_with_lock!(:read, 24)
#   MyResource.all(:lock => :write)

module DataMapper
  # Query has no exposed area for us to add a new option, which is why we
  # introduce a new class to wrap it
  class LockingQuery < Query
    attr_reader :lock

    def initialize(repository, model, options = {})
      options = options.dup
      @lock = options.delete(:lock)
      super
    end
  end

  module Resource
    # Reloads the resource with a write lock
    def lock!
      reload # Where should this go?

      key_conditions = self.class.key.zip(key.nil? ? [] : key).to_hash
      query = DataMapper::LockingQuery.new(
        repository,
        self.class,
        key_conditions.merge(:lock => :write))

      repository.adapter.read(query)

      self
    end
  end

  module Adapters
    class DataObjectsAdapter < AbstractAdapter
      # The dirty part - this method is flagged @private, but I don't have
      # a better way of injecting this code
      def select_statement(query)
        statement, bind_values = super

        if query.is_a?(::DataMapper::LockingQuery)
          if query.lock == :write
            statement << " FOR UPDATE"
          end
        end

        [statement, bind_values]
      end
    end
  end
end
