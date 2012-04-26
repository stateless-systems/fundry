require 'fundry/event'
require 'fundry/payment_state'
require 'fundry/payment_trigger'
require 'fundry/transfer'
require 'fundry/user'
require 'fundry/user/transfer'

module Fundry
  class Payment

    FINALIZED_STATES = %w(rejected canceled complete)

    include DataMapper::Resource
    property   :id, Serial
    property   :user_id,   Integer, required: true
    property   :gateway,   String

    # NOTE The reference and transaction_id could be different in multi-stage
    # payment processes (e.g. Paypal). All messages from the gateway are
    # recorded for posterity.
    property   :reference, Text,      lazy: false, index: true
    property   :transaction_id, Text, lazy: false, index: true
    property   :messages, Json

    # client-ip that initiated this payment.
    property   :client_ip, String
    property   :state,     String,  default: 'new', index: true
    money      :balance,            required: true, precision: 15, scale: 5
    timestamps :at

    has n, :payment_states, constraint: :destroy!
    has n, :triggers, constraint: :destroy!, model: 'Fundry::PaymentTrigger'
    belongs_to :user
    belongs_to :transfer, model: Fundry::Transfer, required: false

    after :create do
      payment_states.create(status: 'new')
      if balance < BigMoney.new(0, :usd)
        meta = user.meta
        meta.update(withdrawn_balance: meta.withdrawn_balance + -balance)
      end
    end

    def complete! detail = ''
      raise "Payment state is already #{state}" if finalized?
      balance < BigMoney.new(0, :usd) ? complete_withdrawal(detail) : complete_deposit(detail)
    end

    def reject! detail = ''
      raise "Payment state is already #{state}" if finalized?
      rejected_withdrawal(detail) if balance < BigMoney.new(0, :usd)
      payment_states.create(status: 'rejected', detail: detail)
    end

    def finalized?
      FINALIZED_STATES.include?(state)
    end

    def worker_path
      '/job/payment'
    end

    def completed?
      state == 'complete'
    end

    # TODO cache it.
    # Paypal US - https://www.paypal.com/us/cgi-bin/webscr?cmd=_display-receiving-fees-outside
    # Paypal AU - https://www.paypal.com/au/cgi-bin/webscr?cmd=_display-receiving-fees-outside
    #           - https://www.paypal.com/au/cgi-bin/webscr?cmd=_display-xborder-fees-outside
    def self.paypal_fees
      # TODO use the tier once we've signed up for a merchant account.
      # cut = case total_monthly_transactions_for 'paypal'
      #   when 0..5000         then 3.40
      #   when 5000..15_000    then 3.00
      #   when 15_000..150_000 then 2.50
      #   else 2.10
      # end
      [ 0.30, 3.40 ]
    end

    # TODO cache it.
    def self.total_monthly_transactions_for gateway
      total = repository.adapter.select <<-SQL
        select coalesce(sum(abs(balance_amount)), 0) from payments
        where gateway = '#{gateway}' and created_at > now () - interval '1 month' and state = 'complete'
      SQL
      total.first
    end

    protected
      def rejected_withdrawal detail = ''
        refund = User::Paypal.get.transfer(user, -balance)
        refund.update(parent: transfer)
        meta = user.meta
        meta.update(withdrawn_balance: meta.withdrawn_balance + balance)
      end

      def complete_deposit detail = ''
        transaction do
          update(transfer: User::Paypal.get.transfer(user, balance))
          payment_states.create(status: 'complete', detail: detail)

          Fundry::Event::Payment::Deposit.create(user_id: user.id, detail: {
            payment: {id: id},
            user:    {id: user.id, name: user.name},
            balance: {amount: balance.amount.to_s, currency: balance.currency.to_s}
          })
        end

        # triggers are executed outside transaction, so any failures can be retried.
        triggers(completed: false).each {|trigger| trigger.process! }
      end

      def complete_withdrawal detail = ''
        transaction do
          payment_states.create(status: 'complete', detail: detail)
          Fundry::Event::Payment::Withdraw.create(user_id: user.id, detail: {
            payment: {id: id},
            user:    {id: user.id, name: user.name},
            balance: {amount: balance.amount.to_s, currency: balance.currency.to_s}
          })
        end
      end
  end # Payment
end # Fundry
