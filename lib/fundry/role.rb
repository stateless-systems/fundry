module Fundry
  class Role

    include DataMapper::Resource
    property :id,       Serial
    # NOTE I would have liked to use enum, but DM doesn't really store them as ENUM on the db and
    #      i hate to write SQL where name = 1 means name = 'admin'
    property :name,     String, unique_index: :userrole
    property :user_id,  Integer, unique_index: :userrole

    timestamps :at
    belongs_to :user
  end
end
