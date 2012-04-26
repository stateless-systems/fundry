require 'dm-core'
require 'data_objects'
require 'uuid'

#--
# TODO: Fork and apply patches to http://github.com/xaviershay/dm-nested-transactions
# The original transaction name generation code generated strings so long postgres complained and truncated.
module DataMapper
  module Resource
    def transaction(&block)
      self.class.transaction(&block)
    end
  end

  class Transaction
    # Overridden to allow nested transactions
    def connect_adapter(adapter)
      if @transaction_primitives.key?(adapter)
        raise "Already a primitive for adapter #{adapter}"
      end

      primitive = if adapter.current_transaction
        adapter.nested_transaction_primitive
      else
        adapter.transaction_primitive
      end

      @transaction_primitives[adapter] = validate_primitive(primitive)
    end
  end

  module NestedTransactions
    def nested_transaction_primitive
      DataObjects::NestedTransaction.create_for_uri(normalized_uri, current_connection)
    end
  end
end

module DataObjects
  class NestedTransaction < Transaction
    attr_reader :connection
    attr_reader :id

    def self.create_for_uri(uri, connection)
      uri = uri.is_a?(String) ? URI::parse(uri) : uri
      DataObjects::NestedTransaction.new(uri, connection)
    end

    # Creates a NestedTransaction bound to an existing connection.
    def initialize(uri, connection)
      @connection = connection
      @id         = UUID.generate
    end

    def close
    end

    def begin
      cmd = "SAVEPOINT \"#{@id}\""
      connection.create_command(cmd).execute_non_query
    end

    def commit
      cmd = "RELEASE SAVEPOINT \"#{@id}\""
      connection.create_command(cmd).execute_non_query
    end

    def rollback
      cmd = "ROLLBACK TO SAVEPOINT \"#{@id}\""
      connection.create_command(cmd).execute_non_query
    end
  end
end
