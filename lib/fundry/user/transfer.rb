require 'fundry/user'
require 'fundry/transfer'

module Fundry
  class User
    # Transfer an amount to another user.
    module Transfer

      def withdraw? amount
        group?(:gateway) || amount <= balance
      end

      # Transfer an amount to another user.
      #
      # ==== Notes
      # A transfer is made up of two transactions a debit and a linked credit (parent_id). The balances of both
      # accounts are updated inside the same transaction.
      #
      # ==== Parameters
      # user<Fundry::User>::        The user to credit.
      # amount<BigMoney>::          A non-zero credit amount.
      # parent<Fundry::Transfer>::  Parent transfer if one exists for this transaction.
      #
      # ==== Returns
      # Fundry::Transfer:: The top of the transaction tree.
      #
      # ==== Raises
      # TransferError
      def transfer user, amount, parent = nil
        assert_kind_of 'user',   user,   User
        assert_kind_of 'amount', amount, BigMoney

        raise TransferError, 'User must be someone else.'        unless user != self
        raise TransferError, 'Amount must be greater than zero.' unless amount > BigMoney.new(0, :usd)
        raise BalanceError,  'Amount exceeds balance.'           unless withdraw? amount

        transaction do
          debit = transfers.create(user: self, balance: -amount, parent: parent)
          debit.children.create(user: user, balance: amount)

          lock!
          user.lock!

          # Updated balances
          self.update(balance: balance - amount)
          user.update(balance: user.balance + amount)

          debit # Return the top of the chain.
        end
      end
    end # Transfer

    include Transfer
  end # User
end # Fundry
