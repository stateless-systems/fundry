require 'haml'
require 'sinatra/tilt'

module Haml
  class Engine::Snowman < Engine
    def parse_tag line
      tag_name, attributes, attributes_hashes, object_ref, nuke_outer_whitespace,
        nuke_inner_whitespace, action, value, last_line = super(line)
      if tag_name.downcase == 'form'
        post = false
        attributes_hashes.map! do |syntax, attributes_hash|
          post = true if attributes_hash.match(/method.*?post/i)
          [syntax, attributes_hash += ", 'accept-charset' => 'utf-8'" ]
        end.compact!
        _insert_tag "%input{type: 'hidden', name: '_utf8', value: '&#9731;'}" if post
      end
      [ tag_name, attributes, attributes_hashes, object_ref, nuke_outer_whitespace,
        nuke_inner_whitespace, action, value, last_line ]
    end

    def _insert_tag line
      tabs = '  '*(@line.tabs + 1)
      text =  tabs + line
      un_next_line tabs + @next_line.text
      @next_line = Line.new text.strip, text.lstrip.chomp, text, @line.index, self, false
    end
  end
end

module Tilt
  class HamlTemplate < Template
    def initialize_engine
      ::Haml::Engine::Snowman
    end

    def prepare
      options = @options.merge(filename: eval_file, line: line)
      @engine = ::Haml::Engine::Snowman.new(data, options)
    end
  end
end
