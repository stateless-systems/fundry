module Job
  module Worker
    def self.registered app
      Dir["#{File.dirname(__FILE__)}/worker/*.rb"].each do |name|
        app.class_eval File.read(name), name, 1
      end
    end
  end
end
