require 'riddle'
require 'riddle/1.10'
require 'fundry/project'

module Fundry
  module Search
    DEFAULTS = {match_mode: :extended2, limit: 9, rank_mode: :sph04}

    # TODO only create one client per unicorn process ?
    def self.client options = {}
      client = Riddle::Client.new
      DEFAULTS.merge(options).each{|k, v| client.send(:"#{k}=", v) if client.respond_to?(:"#{k}=")}
      client
    end

    def self.projects statement, options = {}
      ids     = client(options).query(statement, 'projects')[:matches].map{|p| p[:doc]}
      results = ids.empty? ? [] : Project.all(id: ids, verified: true)
      results.sort{|a, b| ids.index(a.id) <=> ids.index(b.id)}
    end

    #--
    # TODO: Compute cutoff weight using proximity_bm5 algorithm?
    def self.features statement, options = {}
      projects = options.delete(:projects) || []
      cutoff   = options.delete(:cutoff)   || 1

      riddle   = client(options.merge(match_mode: :any))
      riddle.filters << Riddle::Client::Filter.new('project_id', projects, false) unless projects.empty?

      matches  = riddle.query(statement, 'features')[:matches]
      ids      = matches.select{|r| r[:weight] >= cutoff }.map{|p| p[:doc]}
      results  = ids.empty? ? [] : Feature.all(id: ids, deleted_at: nil, state: %w(new pending complete))
      results.sort{|a, b| ids.index(a.id) <=> ids.index(b.id)}
    end
  end
end
