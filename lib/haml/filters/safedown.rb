require 'sanitize'
require 'rdiscount'

module Haml::Filters::Safedown
  include Haml::Filters::Base

  def render text = ''
    ::Sanitize.clean(
      RDiscount.new(text).to_html || '',
      elements:   %w(a b i ol ul li span div table thead th tbody td h1 h2 h3 h4 h5 p),
      attributes: {'a' => %w(href title), 'img' => %w(alt src title)},
      protocols:  {'a' => {'href' => %w(http https)}}
    ) || ''
  end
end
