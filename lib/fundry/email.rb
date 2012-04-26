module Fundry
  class Email
    include DataMapper::Resource

    property :id,         Serial
    property :user_id,    Integer, index: true
    property :from,       Text
    property :to,         Text
    property :subject,    Text
    property :message,    Text
    property :deleted_at, ParanoidDateTime

    timestamps :created_at

    belongs_to :user
  end
end
