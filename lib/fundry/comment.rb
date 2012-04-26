module Fundry
  class Comment
    include DataMapper::Resource
    property   :id,         Serial
    property   :feature_id, Integer, required: true
    property   :user_id,    Integer, required: true
    property   :detail,     Text,    required: true, lazy: false
    timestamps :at

    belongs_to :feature
    belongs_to :user
  end
end
