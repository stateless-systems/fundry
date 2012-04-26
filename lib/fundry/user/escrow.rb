require 'fundry/user'

module Fundry
  class User
    module Escrow
      USERNAME = 'fundry-escrow'

      def self.get
        User.first(username: USERNAME)
      end
    end # Escrow
  end # User
end # Fundry
