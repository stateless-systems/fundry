module Fundry
  class Feature
    module Approval
      def initiate_approval!
        pledges.each {|pledge| FeatureAcceptance.create(pledge: pledge, feature: self) }
      end
    end
    include Approval
  end
end
