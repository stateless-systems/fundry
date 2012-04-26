require 'fundry/user'

module Fundry
  class User
    module Paypal
      USERNAME = 'fundry-paypal'

      def self.get
        User.first(username: USERNAME)
      end
    end # Paypal
  end # User
end # Fundry
