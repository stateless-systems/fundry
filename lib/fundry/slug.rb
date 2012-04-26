require 'string/slug'
module Fundry
  module Slug
    def slug
      String::Slug.new('%d-%s' % [ id, name ])
    end
  end
end
