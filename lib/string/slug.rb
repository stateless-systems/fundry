class String
  class Slug < String
    def initialize string
      replace string.to_s.downcase.gsub(/[\s\-_\.:;!]+/, '-').gsub(/[^\w\-]/, '').gsub(/^-+/, '').gsub(/-+$/, '')
    end

    def + string
      self.class.new "#{to_s}-#{string.to_s}"
    end

    def << string
      replace self + string
    end
  end
end
