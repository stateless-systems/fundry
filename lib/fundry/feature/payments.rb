require 'big_money/serializer'

module Fundry
  class Feature
    #--
    # TODO: Donor is a terrible fucking name for the pledge user since we also have donations!
    # TODO: This module shouldn't be mixed in. It should be an class and used as an object so it's easier to hand
    # around the state and break up into reasonable sized methods for each task thats happening here.
    # TODO: Events so people can actually see what's going on.
    module Payments
      def initiate_refunds!
        pledges.each {|pledge| pledge.retract! notify_donor: true }
      end

      def finalize! logger = Logger.new($stdout, 0)
        transaction do |trx|
          escrow     = User::Escrow.get
          developer  = project.user
          pending    = acceptances(state: 'pending')
          approvals  = acceptances(state: ['accepted', 'pending'])
          rejections = acceptances(state: 'rejected')

          lock!
          developer.meta.lock!
          (approvals + rejections).each do |feedback|
            feedback.pledge.transfer.user.meta.lock!
          end

          logger.info "accepted: #{approvals.length - pending.length}"
          logger.info "pending:  #{pending.length}"
          logger.info "rejected: #{rejections.length}"

          refund = BigMoney.new(0, balance.currency || :usd)
          if rejections.length > approvals.length
            logger.info "Feature rejected by a simple majority vote - issuing refunds"
            logger.info "Moving monies from escrow back to donor account(s) for rejected pledges"
            project.meta.update(pledge_objection: project.meta.pledge_objection + 1)

            rejections.each do |rejection|
              donor    = rejection.pledge.transfer.user
              parent   = rejection.pledge.transfer.children.last
              transfer = escrow.transfer donor, parent.balance, parent
              logger.info "  #{parent.balance.to_explicit_s}:\t#{escrow.username}(#{escrow.id}) -> #{donor.username}(#{donor.id})"

              Fundry::Event::Pledge::Refund.create(
                user_id:    donor.id,
                project_id: project.id,
                feature_id: id,
                detail:     {
                  project: {id: project.id, name: project.name},
                  feature: {id: id, name: name},
                  user:    {id: donor.id, name: donor.name},
                  pledge:  {balance: {amount: transfer.balance.amount.to_s, currency: transfer.balance.currency.to_s}},
                }
              )

              rejection.update(open: false, transfer: transfer)
              refund += parent.balance
            end
          else
            logger.info "Feature approved by a simple majority vote - giving developer the monies"
            project.meta.update(pledge_approval: project.meta.pledge_approval + 1)

            payout! escrow, developer, rejections, logger
          end

          logger.info "Moving monies from escrow to developer account for approved pledges."

          payout     = (balance - refund)
          commission = (balance - refund) * User::Commissions::RATE

          payout! escrow, developer, approvals, logger
          update(balance: payout) if refund.amount > 0

          project.meta.update(
            pledge_pending:          project.meta.pledge_pending - 1,
            pledge_complete:         project.meta.pledge_complete + 1,
            pledge_complete_balance: project.meta.pledge_complete_balance + (approvals.empty? ? 0 : (payout - commission))
          )

          # TODO: Why isn't pledge_pending updated here Barney?
          # TODO: This can't be right. developer == user so all those counts are going to be fucked if you've pledged and also
          # received pledges?
          developer.meta.update(
            pledge_complete: developer.meta.pledge_complete + 1,
            pledge_complete_balance: developer.meta.pledge_complete_balance + (approvals.empty? ? 0 : (payout - commission))
          )
          approvals.each do |approval|
            meta = approval.pledge.transfer.user.meta
            meta.update(pledge_pending: meta.pledge_pending - 1, pledge_approval: meta.pledge_approval + 1)
          end
          rejections.each do |rejection|
            meta = rejection.pledge.transfer.user.meta
            meta.update(pledge_pending: meta.pledge_pending - 1, pledge_objection: meta.pledge_objection + 1)
          end

          trx.commit
        end
      end

      private
        def payout! escrow, developer, acceptances, logger = Logger.new($stdout, 0)
          commission = User::Commissions.get
          acceptances.each do |acceptance|
            donor  = acceptance.pledge.transfer.user
            parent = acceptance.pledge.transfer.children.last

            logger.info "  #{parent.balance.to_explicit_s}:\t#{escrow.username}(#{escrow.id}) -> #{developer.username}(#{developer.id})"
            payout = escrow.transfer developer, parent.balance, parent

            logger.info "  #{(parent.balance * User::Commissions::RATE).to_explicit_s}:\t#{escrow.username}(#{escrow.id}) -> #{commission.username}(#{commission.id})"
            developer.transfer commission, parent.balance * User::Commissions::RATE, payout.children.last

            Fundry::Event::Pledge::Paid.create(
              user_id:    donor.id,
              project_id: project.id,
              feature_id: id,
              detail:     {
                project: {id: project.id, name: project.name},
                feature: {id: id, name: name},
                user:    {id: donor.id, name: donor.name},
                pledge:  {balance: {amount: payout.parent.balance.amount.to_s, currency: payout.parent.balance.currency.to_s}},
              }
            )

            acceptance.update(open: false, transfer: payout)
          end
        end
    end

    include Payments
  end
end
