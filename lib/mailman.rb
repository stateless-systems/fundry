require 'haml'
require 'pony-express'
require 'nokogiri'

class Mailman
  attr_reader :path
  NokogiriOptions = Nokogiri::XML::ParseOptions::NOENT | Nokogiri::XML::ParseOptions::RECOVER

  def initialize
    @path = File.absolute_path "#{File.dirname(__FILE__)}/../views"
    @layout = "#{@path}/mail/layout.haml"
  end

  def send template, options, locals={}, user=nil
    template += '.haml'
    template  = "#{@path}/#{template}"

    File.open(template) do |fh|
      html = body(fh, {subject: options[:subject], unsubscribe: nil}.merge(locals))
      text = plain_text_message(html)
      options.merge! via: :sendmail

      PonyExpress.mail options.update(text: text, html: html)

      # Errors are not critical here, this is only a cc to local inbox.
      if user
        begin
          attrs = %w(to from subject).map(&:to_sym)
          text.gsub!(/^ */m, '')
          email = user.emails.create(options.select {|k,v| attrs.include?(k)}.merge(message: text))
          raise email.errors.map(&:to_s).join("\n") unless email.errors.empty?
          nil
        rescue Exception => e
          e
        end
      end
    end
  end

  def body template, locals
    template = template.respond_to?(:read) ? template.read : template
    engine   = Haml::Engine.new File.read(@layout)
    scope    = Scope.new(@path, locals)
    document = Nokogiri::HTML(engine.render(scope, locals) { Haml::Engine.new(template).render(scope, locals) })

    # If there are any plain text urls make them proper html anchors.
    document.xpath("//text()").each do |node|
      next if node.parent && node.parent.name == 'a'
      text = node.text
      if (text.match(URI::regexp))
        sibling, parent = node.previous, node.parent
        node.remove
        text.gsub!(URI::regexp){|m| $1.match(/https?/i) ? %Q{<a href="#{m}">#{m}</a>} : m}
        case
          when sibling
            sibling.after(text)
          when parent.children.empty?
            parent.inner_html = text
          else
            parent.children.before(text)
        end
      end
    end
    document.to_html
  end

  class Scope
    def initialize path, locals={}
      @path, @locals = path, locals
    end

    # TODO rip this out of here and Fundry::Web into a helper module.
    def money money, user=nil
      currency = user ? user.currency : :usd
      html = <<-HTML
        <abbr class="money" title="#{money.to_local_s(currency)}">#{money.to_explicit_s}</abbr>
      HTML
      html.strip
    end

    def partial template, options={}
      dir, file = File.split template
      engine = Haml::Engine.new(File.read("#{@path}/#{dir}/_#{file}.haml"), options)
      engine.render(self, @locals)
    end
  end

  protected
  def plain_text_message html
    dom  = Nokogiri::HTML.parse(html, nil, nil, NokogiriOptions)
    dom.css('body').text
  end

end
