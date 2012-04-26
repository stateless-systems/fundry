module Haml::Filters::Code
  include Haml::Filters::Base

  def render(text)
    Haml::Helpers.html_escape(text).gsub(/\n/, '<br/>')
  end
end
