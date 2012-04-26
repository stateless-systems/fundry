module Fundry
  class Pledge
    module Retractable
      def retract! options={}
        raise TransferError, "The pledge has already been retracted or deleted." if deleted_at

        if feature.state == 'complete'
          raise TransferError, "The feature has been marked as complete. You cannot retract this pledge now."
        end

        refund = Pledge.transaction do
          lock!
          feature.lock!
          transfer.user.meta.lock!
          feature.project.meta.lock!

          total_pledges = feature.pledges.count

          destroy
          escrow = User::Escrow.get
          parent = transfer.children.last
          user   = transfer.user

          user.meta.update(
            pledge:                 user.meta.pledge - 1,
            pledge_pending:         user.meta.pledge_pending - 1,
            pledge_pending_balance: user.meta.pledge_pending_balance - parent.balance
          )
          feature.project.meta.update(
            pledge:                 feature.project.meta.pledge - 1,
            pledge_pending:         feature.project.meta.pledge_pending - 1,
            pledge_pending_balance: feature.project.meta.pledge_pending_balance - parent.balance
          )

          attrs = { balance: feature.balance - parent.balance }

          # if feature was not added by project owner and all pledges have been retracted then
          # remove the feature.
          if options[:delete] && total_pledges == 1 && feature.user_id != feature.project.user_id
            attrs.merge!(deleted_at: Time.now)
          end

          unless feature.update(attrs)
            $stderr.puts feature.errors.flatten.map(&:to_s).join("\n")
            raise TrasferError, 'Unable to update feature balance.'
          end

          escrow.transfer(user, parent.balance, parent)
        end

        user, project = transfer.user, feature.project
        attrs         = {
          user_id:    user.id,
          project_id: project.id,
          feature_id: feature.id,
          detail:     {
            user:    {id: user.id, name: user.name},
            project: {id: project.id, name: project.name},
            feature: {id: feature.id, name: feature.name},
            pledge:  {id: id, balance: {amount: transfer.balance.amount.to_s, currency: transfer.balance.currency.to_s}},
          }
        }

        Fundry::Event::Pledge::Retract.create(attrs)

        schedule_work :"notify-donor" if options[:notify_donor]
        schedule_work :"notify-owner" if options[:notify_owner]
        refund
      end
    end # Retractable
    include Retractable
  end # Pledge
end # Fundry
