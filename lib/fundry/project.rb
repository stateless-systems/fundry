require 'uri/sanitize'
require 'fundry/project_meta'
require 'fundry/project/verification'
require 'fundry/project/pledge'
require 'fundry/slug'
require 'fundry/verification'

module Fundry
  class Project
    include DataMapper::Resource
    include Fundry::Slug

    property :id,               Serial
    property :user_id,          Integer, required: true
    property :summary,          String,  length: 128,    required: true
    property :detail,           Text,    required: true
    property :name,             String,  length: 64,     required: true
    property :twitter,          String,  length: 15
    property :web,              String,  length: 250,    required: true
    property :verified,         Boolean, default: false, index: :verified

    property :disabled_at,      DateTime
    property :deleted_at,       ParanoidDateTime

    timestamps :at

    has 1, :meta, Fundry::ProjectMeta
    has n, :donations
    has n, :events
    has n, :features
    has n, :abuse_reports
    has n, :verifications, Fundry::Verification

    belongs_to :user

    validates_with_method :web, method: :validate_web

    after :create do
      Fundry::ProjectMeta.create(project_id: id) # Avoid project.meta.first_or_create all over the joint.
      Fundry::Event::Project::Create.create(
        user_id:    user.id,
        project_id: id,
        detail:     {
          project: {id: id, name: name},
          user:    {id: user.id, name: user.name}
        }
      )
    end

    before :save do
      if attribute_dirty?(:web) && self.web != self.original_attributes[properties[:web]]
        self.verified = false
      end
    end

    def funding
      features.pending.inject(BigMoney.new(0, :usd)){|a, p| a + p.balance} + meta.donation_balance
    end

    # TODO Complex query - either memcache it or make sure varnish only
    #      invalidates the relevant page every few hours.
    def self.top
      DataMapper::SqlCollection.new(
        lambda{|offset, limit|
          repository.adapter.select(%q{
            select
              pr.id,
              sum(abs(coalesce(fe.balance_amount, 0))) as pledges
            from projects pr
            left join features fe on pr.id = fe.project_id
            where
              pr.verified is true
              and pr.deleted_at is null
              and (
                fe.state in('new', 'pending')
                or fe.state is null
              )
            group by pr.id, pr.created_at
            order by pledges desc, pr.created_at desc
            offset ?
            limit  ?
          }, offset, limit).map{|row| get(row.id) }
        },
        lambda{
          repository.adapter.select(%q{
            select count(distinct pr.id) as count
            from projects pr
            left join features fe on pr.id = fe.project_id
            where
              pr.verified is true
              and pr.deleted_at is null
              and (
                fe.state in ('new', 'pending')
                or fe.state is null
              )
          }).first
        }
      )
    end

    def self.awaiting_confirmation options={}
      ids = repository.adapter.select(%q{
        select v.project_id from verifications v join
        (select project_id, max(created_at) as created_at from verifications group by project_id) latest
        using(project_id, created_at) where v.verified is false and v.rank > 0
      })
      Project.all(options.merge(id: ids))
    end

    def self.count_awaiting_confirmation
      repository.adapter.select(%q{
        select count(*) from verifications v join
        (select project_id, max(created_at) as created_at from verifications group by project_id) latest
        using(project_id, created_at) where v.verified is false and v.rank > 0
      }).first
    end

    def worker_path
      '/job/project'
    end

    def active?
      !disabled_at
    end

    protected
      def validate_web
        sanitized = URI.sanitize(web.to_s)
        sanitized.is_a?(URI::HTTP) || [false, 'Must be http(s) scheme.']
        %r{http(s)?://[^.]+\.[^.]+}.match(sanitized.to_s) || [false, %q{Web doesn't look like a valid URI.}]
      rescue => error
        [false, error.message]
      end

  end # Project
end # Fundry
