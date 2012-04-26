require 'fundry/transfer'
require 'fundry/feature_acceptance'
require 'fundry/pledge/retract'

module Fundry
  class Pledge
    include DataMapper::Resource
    property   :id,          Serial
    property   :feature_id,  Integer, required: true
    property   :transfer_id, Integer, required: true
    property   :client_ip,   String
    timestamps :at

    property   :deleted_at, ParanoidDateTime

    belongs_to :feature
    belongs_to :transfer

    has 1, :acceptance, model: Fundry::FeatureAcceptance

    #--
    # TODO: Well this shit needs to be golfed or removed.
    after :create do
      user, project = transfer.user, feature.project
      options       = {
        user_id:    user.id,
        project_id: project.id,
        feature_id: feature.id,
        detail:     {
          user:    {id: user.id, name: user.name},
          project: {id: project.id, name: project.name},
          feature: {id: feature.id, name: feature.name}
        }
      }
      Fundry::Event::Feature::Create.create(options) if feature.pledges.size == 1
      options[:detail][:pledge] = {
        id:      id,
        balance: {amount: (-transfer.balance.amount).to_s, currency: transfer.balance.currency.to_s}
      }
      Fundry::Event::Pledge::Create.create(options)
    end

    def worker_path
      '/job/pledge'
    end

    def self.balance
      -all.inject(BigMoney.new(0, :usd)){|acc, p| acc + p.transfer.balance}
    end

    def self.top
      DataMapper::SqlCollection.new(
        lambda{|offset, limit|
          repository.adapter.select(%q{
            select
              pl.id,
              sum(abs(tr.balance_amount)) as pledge
            from pledges pl
            inner join transfers tr on tr.id = pl.transfer_id
            where pl.deleted_at is null
            group by pl.id
            order by pledge desc
            offset ?
            limit ?
          }, offset, limit).map{|row| get(row.id)}
        },
        lambda{
          # TODO: Check pledge transfer state?
          repository.adapter.select(%q{
            select count(*)
            from pledges where deleted_at is null
          }).first
        }
      )
    end

    def feature
      Feature.with_deleted { Feature.get(feature_id) }
    end

    def self.pending
      all(self.feature.state => ['new', 'pending'])
    end

    def self.complete
      all(self.feature.state => 'complete')
    end
  end
end # Fundry
