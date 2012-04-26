require 'fundry/user'

module Fundry
  class User
    module Anonymous
      USERNAME = 'anonymous'

      # TODO create holding image for anonymous/default on gravatar.com

      def self.get
        User.first(username: USERNAME)
      end

    end # Site
  end # User
end # Fundry


