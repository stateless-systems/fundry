module Fundry
  class Project
    module Pledgable
      def pledge donor, amount, feature, client_ip=nil
        raise TransferError, "Cannot pledge to unverified project." unless verified?
        balance = BigMoney.parse!(amount).exchange(:usd)
        transaction do
          feature = features.create(feature.merge({user_id: donor.id}))
          pledge  = donor.pledge(feature, balance, client_ip)
        end
        balance
      end
    end # Pledgable
    include Pledgable
  end # Project
end # Fundry
