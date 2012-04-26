require File.join(File.dirname(__FILE__), '..', 'fundry')

module Fundry
  module Cli
    def self.bin
      File.basename($0).gsub(/-/, ' ')
    end

    def self.root
      Fundry.root
    end
  end # Cli
end # Fundry
