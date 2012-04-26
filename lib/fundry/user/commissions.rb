require 'fundry/user'

module Fundry
  class User
    module Commissions
      RATE     = 0.05
      USERNAME = 'fundry-commissions'

      def self.get
        User.first(username: USERNAME)
      end
    end # Commissions
  end # User
end # Fundry
