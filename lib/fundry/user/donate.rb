require 'fundry/user'
require 'fundry/user/transfer'
require 'fundry/donation'

module Fundry
  class User
    # Donate an amount to a project.
    module Donate

      # Donate an amount to a project.
      #
      # ==== Notes
      # * Wraps the donation and transfer inside the same transaction.
      # * Amounts are transfered into the lead developers user account.
      #
      # ==== Parameters
      # project<Fundry::Project>:: The project to credit.
      # amount<BigMoney>::         A non-zero credit amount.
      # anonymous<Boolean>::       Don't take credit for the donation.
      #
      # ==== Returns
      # Fundry::Donation
      #
      # ==== Raises
      # TransactionError
      def donate project, amount, anonymous=false, message=nil, client_ip=nil
        transaction do
          meta.lock!
          project.meta.lock!

          transfer = transfer(project.user, amount)
          project.donations.create(transfer: transfer, anonymous: anonymous, message: message, client_ip: client_ip)

          meta.update(donation: meta.donation + 1, donation_balance: meta.donation_balance + amount)
          project.meta.update(
            donation:         project.meta.donation + 1,
            donation_balance: project.meta.donation_balance + amount
          )

          transfer # Return the top of the chain.
        end
      end
    end # Donate

    include Donate
  end # User
end # Fundry

