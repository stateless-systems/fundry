require 'redis'
require 'moneta/redis'

module Moneta
  class Redis2 < Redis
    def key? key
      @cache.exists(key)
    end

    def store key, value, options = {}
      if options[:expires_in].to_i > 0
        @cache.setex(key, options[:expires_in], Marshal.dump(value))
      else
        @cache.set(key, Marshal.dump(value))
      end
    end

    def delete key
      value = @cache[key]
      @cache.del(key) if value
      value ? Marshal.load(value) : value
    end

    def [] key
      value = @cache.get(key)
      value ? Marshal.load(value) : value
    end

    def update_key(key, options = {})
      store(key, self[key], options)
    end
  end
end
