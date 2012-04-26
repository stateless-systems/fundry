require 'fundry/user'

module Fundry
  class User
    module Site
      USERNAME = 'fundry'

      def self.get
        User.first(username: USERNAME)
      end
    end # Site
  end # User
end # Fundry

