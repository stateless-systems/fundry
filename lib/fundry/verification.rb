module Fundry
  class Verification
    include DataMapper::Resource

    property :id,         Serial,  max: 2**63-1
    property :project_id, Integer, index: :verified
    property :verified,   Boolean, default: false
    property :rank,       Integer, index: :verified, default: 0
    property :message,    Text

    timestamps :created_at
    belongs_to :project

    after :create do
      project.update(verified: self.verified)
    end
  end # Verification
end # Fundry
