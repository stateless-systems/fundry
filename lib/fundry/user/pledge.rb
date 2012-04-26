require 'fundry/feature'
require 'fundry/pledge'
require 'fundry/user'
require 'fundry/user/transfer'

module Fundry
  class User
    # Pledge an amount to a feature.
    module Pledgable

      # Pledge an amount to a feature.
      #
      # ==== Notes
      # * Wraps the pledge and transfer inside the same transaction.
      # * Amounts are transfered into the fundry escrow account.
      #
      # ==== Parameters
      # feature<Fundry::Feature>:: The feature to pledge.
      # amount<BigMoney>::         A non-zero credit amount.
      #
      # ==== Returns
      # Fundry::Pledge
      #
      # ==== Raises
      # TransferError
      def pledge feature, amount, client_ip=nil
        assert_kind_of 'feature', feature, Feature
        assert_kind_of 'amount',  amount,  BigMoney

        raise TransferError, "+feature+ is already #{feature.status}." if %w{rejected complete}.include?(feature.state)

        transaction do
          meta.lock!
          feature.lock!
          feature.project.meta.lock!

          parent = nil
          escrow = User::Escrow.get
          if existing = feature.pledges_by_user_id(self.id).first
            parent  = existing.retract!.children.last
            # datamapper IM fail! :(
            feature = Feature.get(feature.id)
          end

          # user balances might have changed in the retract above, should've known better
          # IM no workey.
          transfer = User.get(id).transfer(User::Escrow.get, amount, parent)
          feature.pledges.create(transfer: transfer, client_ip: client_ip)

          # NOTE We need to undelete a feature just in case it got marked deleted in
          #      an overlapping pledge retraction.
          feature.update(balance: feature.balance + amount, deleted_at: nil)

          # TODO Figure out why we have to reload to avoid dupes in the collection.
          feature.pledges.reload

          meta.update(
            pledge:                 meta.pledge + 1,
            pledge_pending:         meta.pledge_pending + 1,
            pledge_pending_balance: meta.pledge_pending_balance + amount
          )

          feature.project.meta.update(
            pledge:                 feature.project.meta.pledge + 1,
            pledge_pending:         feature.project.meta.pledge_pending + 1,
            pledge_pending_balance: feature.project.meta.pledge_pending_balance + amount
          )

          transfer # Return the top of the chain.
        end
      end

    end # Pledgable

    include Pledgable
  end # User
end # Fundry

