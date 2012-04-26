module Fundry
  class AbuseReport
    include DataMapper::Resource
    property   :id,         Serial
    property   :project_id, Integer, unique_index: :report
    property   :user_id,    Integer, unique_index: :report
    timestamps :created_at

    belongs_to :project
    belongs_to :user
  end
end
