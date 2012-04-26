require 'fundry/transfer'

module Fundry
  class Donation
    include DataMapper::Resource
    property   :id,          Serial
    property   :project_id,  Integer, required: true
    property   :transfer_id, Integer, required: true
    property   :anonymous,   Boolean, required: true, default: false
    property   :message,     Text
    property   :client_ip,   String
    timestamps :at

    belongs_to :project
    belongs_to :transfer, model: Fundry::Transfer

    #--
    # TODO: Well this shit needs to be golfed or removed.
    after :create do
      Fundry::Event::Donation::Create.create(
        user_id:    transfer.user.id,
        project_id: project.id,
        detail:     {
          user:    {id: transfer.user.id, name: transfer.user.name},
          project: {id: project.id, name: project.name},
          donation: {
            id:        id,
            balance:   {amount: (-transfer.balance.amount).to_s, currency: transfer.balance.currency.to_s},
            anonymous: anonymous
          }
        }
      )
    end

    def self.top
      DataMapper::SqlCollection.new(
        lambda{|offset, limit|
          repository.adapter.select(%q{
            select
              d.id,
              sum(abs(tr.balance_amount)) as donation
            from donations d
            inner join transfers tr on tr.id = d.transfer_id
            where d.anonymous is false
            group by d.id
            order by donation desc
            offset ?
            limit ?
          }, offset, limit).map{|row| get(row.id) }
        },
        lambda{
          repository.adapter.select(%q{
            select count(*)
            from donations d
            where d.anonymous is false
          }).first
        }
      )
    end

    def user
      anonymous ? User::Anonymous.get : transfer.user
    end
  end # Donation
end # Fundry
