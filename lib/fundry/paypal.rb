require 'paypal'
require 'open-uri'

module Fundry
  class Paypal < ::Paypal
    CONFIG = YAML.load <<-EOF
      :production: &defaults
        :nvp:       'https://api-3t.paypal.com/nvp'
        :user:      'XXX'
        :password:  'XXX'
        :signature: 'XXX'
        :endpoint:  'https://www.paypal.com/webscr'
      :development:
        <<: *defaults
        :nvp:       'https://api-3t.sandbox.paypal.com/nvp'
        :user:      'XXX'
        :password:  'XXX'
        :signature: 'XXX'
        :endpoint:  'https://www.sandbox.paypal.com/webscr'
    EOF

    attr_reader :config

    def initialize env
      @config = CONFIG[env] or raise ArgumentError, "Unable to load config for #{env}"
      super config[:nvp], config[:user], config[:password], config[:signature]
    end

    # https://cms.paypal.com/us/cgi-bin/?&cmd=_render-content&content_ID=developer/e_howto_api_nvp_r_SetExpressCheckout
    def deposit return_url, cancel_url, email, balance
      perform(
        method:             'SetExpressCheckout',
        paymentaction:      'Sale',
        returnurl:          return_url,
        cancelurl:          cancel_url,
        email:              email,
        amt:                '%.2f' % balance.amount,
        reqconfirmshipping: 0,
        noshipping:         1,
        allownote:          0,
        brandname:          'Fundry',
        desc:               'Fundry deposit %s' % balance.to_explicit_s,
      )
    end

    def confirm_deposit token, payer_id, balance, ipn_responder_url
      perform(
        method:        'DoExpressCheckoutPayment',
        paymentaction: 'Sale',
        token:          token,
        payerid:        payer_id,
        amt:            '%.2f' % balance.amount,
        notifyurl:      ipn_responder_url
      )
    end

    def withdraw email, balance
      perform(
        method:       'MassPay',
        emailsubject: 'Fundry Withdrawal',
        currencycode: 'USD',
        receivertype: 'EmailAddress',
        l_email0:     email,
        l_amt0:       '%.2f' % balance.amount
      )
    end

    def payment_url token
      config[:endpoint] + "?cmd=_express-checkout&useraction=commit&token=#{token}"
    end

    def validate message
      response = open(config[:endpoint] + '?cmd=_notify-validate&' + message).read
      response =~ /VERIFIED/ ? true : false
    end

    def process_checkout checkout, payment
      gross = BigMoney.parse!('%s %s' % checkout.values_at(:amt, :currencycode))

      # fee is not sent through unless payment was completed.
      fee   = checkout.key?(:feeamt) ?
        BigMoney.parse!('%s %s' % checkout.values_at(:feeamt, :currencycode))
        : BigMoney.new(0, :usd)

      status = PaymentState.new(checkout[:paymentstatus])

      if status.completed?
        payment.update(
          balance: gross - fee,
          transaction_id: checkout[:transactionid],
          messages: payment.messages + [ checkout ]
        )
        payment.complete!
      else
        payment.update(transaction_id: checkout[:transactionid], messages: payment.messages + [ checkout ])
        payment.payment_states.create(status: status)
      end
      [ gross, fee ]
    end

    def process_ipn payment, params
      status = PaymentState.new(params['payment_status'])

      if !payment.completed? and status.completed?
        gross = BigMoney.parse('%s %s' % params.values_at('mc_gross', 'mc_currency'))
        fee   = BigMoney.parse('%s %s' % params.values_at('mc_fee',   'mc_currency'))

        if payment.balance != (gross - fee)
          $stderr.puts "[ PAYPAL ] - Initial payment is different from Paypal gross for transaction id: #{txn_id}"
          $stderr.puts "[ PAYPAL ] - Paypal message: #{params.inspect}"
          $stderr.puts "[ PAYPAL ] - Updating balance for this transaction on fundry"
        end

        payment.update(balance: gross-fee, messages: payment.messages + [ params ])
        payment.complete!
      else
        payment.update(messages: payment.messages + [ params ])
        payment.reject! if payment.state != status && !payment.finalized? && status.rejected?
      end
    end

    class PaymentState < String

      STATES = {
        denied:    'rejected',
        pending:   'pending',
        completed: 'complete'
      }

      def initialize value
        value = value && value.to_s.downcase.to_sym
        raise ArgumentError, "Invalid Paypal payment state #{value}" unless value && STATES.key?(value)
        super(STATES[value])
      end

      def completed?
        self == 'complete'
      end

      def rejected?
        self == 'rejected'
      end

      def pending?
        self == 'pending'
      end
    end
  end # Paypal
end # Fundry
