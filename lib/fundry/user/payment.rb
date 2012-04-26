require 'fundry/user'
require 'fundry/payment'

module Fundry
  class User
    module Payment

      # Deposit an amount from a payment gateway to fundry.
      #
      # ==== Notes
      # * Wraps the payment and transfer inside the same transaction.
      # * All currencies will be exchanged to USD _before_ the deposit is made.
      # * The original amount and currency are stored in Fundry::Payment.balance property.
      #
      # ==== Parameters
      # amount<BigMoney>:: A non-zero deposit amount.
      # reference<String>:: Gateway reference information if any.
      # client_ip<String>:: Client IP that initiated this payment.
      #
      # ==== Returns
      # Fundry::Payment
      #
      # ==== Raises
      # TransactionError
      #--
      # TODO: Pass ActiveMerchant junk instead.
      def deposit amount, reference='', messages=[], client_ip=nil
        payments.create(
          balance: amount.exchange(:usd),
          gateway: 'paypal',
          reference: reference,
          messages: messages,
          client_ip: client_ip
        )
      end

      # Withdraw an amount from fundry to a payment gateway.
      #
      # ==== Notes
      # * Wraps the payment and transfer inside the same transaction.
      # * Withdrawals are all in USD to the payment gateway.
      #
      # ==== Parameters
      # amount<BigMoney>:: A non-zero withdrawal amount.
      # reference<String>:: Gateway reference information if any.
      # client_ip<String>:: Client IP that initiated this payment.
      #
      # ==== Returns
      # Fundry::Payment
      #
      # ==== Raises
      # TransactionError
      #--
      # TODO: Pass ActiveMerchant junk instead.
      def withdraw amount, reference='', client_ip=nil
        transaction do
          transfer = transfer(User::Paypal.get, amount.exchange(:usd))
          payments.create(
            transfer: transfer,
            balance: -(amount.exchange(:usd)),
            gateway: 'paypal',
            reference: reference,
            client_ip: client_ip
          )
        end
      end
    end # Payment

    include Payment
  end # User
end # Fundry

