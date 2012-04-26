module Fundry
  class Subscription

    include DataMapper::Resource
    property   :id,             Serial
    property   :user_id,        Integer,  unique_index: true
    property   :updates,        Boolean,  default: true        # newsletters etc.
    property   :reminders,      Boolean,  default: true        # verification reminders etc.
    property   :token,          String,   index: true
    timestamps :at

    belongs_to :user

    before :create do
      hash = Digest::SHA1.hexdigest('some salt' + user.username + Time.now.to_f.to_s)
      self.token = Integer('0x' + hash).to_s(36)
    end
  end
end
