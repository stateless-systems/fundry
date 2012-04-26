# Emulate DataMapper::Collection .slice and .size for SQL.
#
# Yes it's a hack to get pagination working when we require more complex queries than DM can do through it's stupid
# query abstraction.
#--
# TODO: Move to datamapper/sql_collection.
module DataMapper
  class SqlCollection
    # Slice callback must take exactly two values, offset and limit (in this order).
    def initialize slice, size
      @slice, @size = slice, size
    end

    def slice offset, limit
      @slice.call(offset, limit)
    end

    def size
      @size.call.to_i
    end

    def empty?
      size == 0
    end
  end # SqlCollection
end # DataMapper

