require 'dm-types/yaml'
require 'fundry/user'
require 'fundry/project'

module Fundry
  class Event
    include DataMapper::Resource
    property   :id,         Serial,        required: true, max: 2**63-1
    property   :type,       Discriminator, required: true, index: true
    property   :user_id,    Integer,       index: true
    property   :project_id, Integer,       index: true
    property   :feature_id, Integer,       index: true
    property   :detail,     Yaml,          required: true
    timestamps :created_at

    belongs_to :user,    Fundry::User
    belongs_to :project, Fundry::Project
    belongs_to :feature, Fundry::Feature

    def feature_slug
      detail[:feature] ? String::Slug.new(detail[:feature][:id]) + detail[:feature][:name] : ''
    end

    def project_slug
      detail[:project] ? String::Slug.new(detail[:project][:id]) + detail[:project][:name] : ''
    end

    # override this if you need something less generic.
    def title
      self.class.to_s.gsub(/::/, ' ')
    end

    module User
      class Create < Event; end
    end # User

    module Project
      class Create < Event; end
    end # Project

    module Feature
      class Create < Event; end
    end # Feature

    module Pledge
      class Create < Event
        def title; 'Pledged' end
      end
      class Retract < Event
        def title; 'Retracted Pledge' end
      end
      class Paid < Event
        def title; 'Paid Pledge' end
      end
      class Refunded < Event
        def title; 'Refunded Pledge' end
      end
    end # Pledge

    module Donation
      class Create < Event; end
    end # Donation

    module Payment
      class Deposit < Event; end
      class Withdraw < Event; end
    end # Payment
  end # Event
end # Fundry
