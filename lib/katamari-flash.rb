class KatamariFlash < Hash
  class List < Array
    def to_s delim = '<br/>'
      map(&:to_s).join(delim)
    end
  end
  def []= k, v
    super(k, List.new(fetch(k, []) + [v]))
  end

  def self.create other={}
    instance = self.new
    other.each {|k,v| instance[k] = v } if other
    instance
  end
end
