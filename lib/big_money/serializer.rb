# encoding: utf-8
require 'big_money'
require 'big_money/exchange'

class BigMoney
  module Serializer
    def to_local_s(currency)
      local = exchange(currency)
      self.currency == local.currency ? to_explicit_s : "~%s" % local.to_explicit_s
    end

    def to_explicit_s
      to_s("%1.#{currency.offset}f%s")
    end

    def whole
      to_s("%1d")
    end

    def fraction
      to_s("%.#{currency.offset}f")[-(currency.offset+1)..(-currency.offset+1)]
    end

    #--
    # YICK! I swore I'd never do this but googles stupid event tracker requires an integer.
    def cents_usd
      (exchange(:usd).amount * 100).to_i
    end
  end

  include Serializer
end
