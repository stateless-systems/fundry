require 'big_money/parser'

class BigMoney
  class ParserError < StandardError; end

  # ==== Raises
  #
  #--
  # TODO: Get explicit about why money couldn't be parsed.
  module ParserVerbose
    def parse! money
      parse(money) or raise ParserError, "Unable to parse '#{money}' as money."
    end
  end # ParserVerbose

  extend Parser
  extend ParserVerbose
end # BigMoney
