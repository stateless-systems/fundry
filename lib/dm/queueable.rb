require 'peon'
module DataMapper
  module Resource
    def schedule_work action_name, params={}
      Peon.enqueue 'fundry', { action: action_name, resource: worker_path, id: id, params: params }
    end
    def worker_path
      raise NoMethodError, "you need to override this method in your resource"
    end
  end
end
