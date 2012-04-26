# All monetary transaction related request handling.
# TODO: sinatra_paypal
# TODO: Production Paypal credentials.

require 'fundry/paypal'

module Fundry
  class Web
    module Payments

      WITHDRAW_FEE_CAP = BigMoney.new(50, :usd)

      module Helpers
        def paypal
          Fundry::Paypal.new self.class.production?  ? :production : :development
        end
      end

      def self.registered app
        app.helpers Helpers

        app.post '/donation' do
          authenticate!
          donation   = params['donation']
          @anonymous = !!donation['anonymous']
          @message   = donation['message'] && !donation['message'].empty? ? donation['message'] : nil
          @project   = Project.get(donation['project_id']) or raise Sinatra::NotFound
          begin
            @balance  = BigMoney.parse!(donation['amount']).exchange(:usd)
            @donation = user.donate(@project, @balance, @anonymous, @message, client_ip)
          rescue BigMoney::ParserError, TransferError => error
            flash.now[:error] = error.message
            haml :"donation/new"
          else
            flash[:analytics] = ['donation', 'create', @project.id.to_s, @balance.cents_usd]
            flash[:success]   = 'Donated %s to %s.' % [@balance, @project.name]
            redirect url(:project, @project.slug, :donation, {order: 'new'})
          end
        end

        app.get '/deposit' do
          authenticate!
          @paypal_fee, @paypal_cut = Fundry::Payment.paypal_fees
          haml :deposit
        end

        app.post '/deposit' do
          authenticate!
          begin
            balance  = BigMoney.parse!(params['deposit']['amount']).exchange(:usd)

            return_url, cancel_url = absolute_url(:deposit, :confirm), absolute_url(:deposit, :cancel)
            checkout = paypal.deposit return_url, cancel_url, user.email, balance

            raise TransferError.new(checkout[:l_longmessage0]) unless checkout[:ack] =~ /success/i
            payment = user.deposit balance, checkout[:token], [ checkout ], client_ip

            # combined signup + deposit + pledge/donate
            if params.include?('feature')
              params['feature']['user_id'] = user.id
              data = { feature: params['feature'], pledge: params['pledge'], client_ip: client_ip }
              payment.triggers.create what: 'feature',  data: data
            elsif params.include?('donation')
              data = { donation: params['donation'], client_ip: client_ip }
              payment.triggers.create what: 'donation', data: data
            end

          rescue BigMoney::ParserError, TransferError => error
            flash.now[:error] = error.message
            haml :deposit
          else
            redirect paypal.payment_url checkout[:token]
          end
        end

        app.get '/deposit/confirm' do
          authenticate!
          payment = Payment.first(reference: params[:token]) or Sinatra::NotFound
          begin
            ipn_responder_url = ENV['PAYPAL_IPN_URL'] || absolute_url(:paypal, :ipn)
            checkout = paypal.confirm_deposit params[:token], params[:PayerID], payment.balance, ipn_responder_url

            raise TransferError.new(checkout[:l_longmessage0]) unless checkout[:ack] =~ /success/i

            gross, fee = paypal.process_checkout(checkout, payment)
          rescue BigMoney::ParserError, TransferError => error
            flash[:error] = error.message
            redirect url(:deposit)
          else
            task = payment.user.username == User::Anonymous::USERNAME ? 'donated' : 'deposited'
            flash[:analytics] = ['deposit', 'create', payment.user.id.to_s, payment.balance.cents_usd]
            flash[:success]   = '%s %s (%s minus a Paypal fee of %s)%s' % [
              (gross-fee).to_explicit_s,
              task,
              gross.to_explicit_s,
              fee.to_explicit_s,
              payment.completed? ? '.' : ' pending PayPal confirmation.'
            ]

            session.delete(:auth) if user.username == User::Anonymous::USERNAME
            trigger = payment.triggers.first
            case
              when trigger && trigger.what == 'donation'
                redirect url(:project, trigger.project.slug, :donation, {order: 'new'})
              when trigger && trigger.what == 'feature'
                redirect url(:project, trigger.project.slug, :pledge, {order: 'new'})
              else
                redirect url(:profile)
            end
          end
        end

        app.get '/deposit/cancel' do
          authenticate!
          payment = Payment.first(reference: params[:token]) or Sinatra::NotFound
          payment.payment_states.create(status: 'canceled')
          if user.username == User::Anonymous::USERNAME
            session.delete(:auth)
            flash[:error] = 'Donation canceled.'
            redirect url(:project, payment.triggers.first.project.slug)
          else
            flash[:error] = 'Deposit canceled.'
            redirect url(:profile)
          end
        end

        app.get '/withdraw' do
          authenticate!
          haml :withdraw
        end

        app.post '/withdraw' do
          authenticate!
          payment, transfer, net, fee = nil, nil, BigMoney::ZERO, BigMoney::ZERO
          begin
            balance  = BigMoney.parse!(params['withdraw']['amount']).exchange(:usd)
            raise(BalanceError, 'Amount exceeds balance.') if user.balance < balance

            # TODO: Why is this in a controller!?
            # 2% surcharge capped at $50 to cover paypal fees. We'll be making a tiny bit
            # extra since we'll be only paying 1.6% on the total.
            fee      = BigMoney.new((balance.amount * 0.02).round(2), balance.currency)
            net      = balance - fee
            fee, net = WITHDRAW_FEE_CAP, balance - WITHDRAW_FEE_CAP if fee > WITHDRAW_FEE_CAP

            payment  = user.withdraw net, '', client_ip
            response = paypal.withdraw params[:withdraw][:paypal], net

            # success or successwithwarning is good.
            raise TransferError.new(response[:l_longmessage0]) unless response[:ack].match(/success/i)
            transfer = user.transfer(User::Commissions.get, fee)
            payment.complete!
          rescue BigMoney::ParserError, TransferError => error
            # rollback payment.
            @paypal = params[:withdraw][:paypal]
            @amount = params[:withdraw][:amount]
            payment.reject!(error.message) if payment

            # rollback fee deduction.
            if transfer
              refund = BigMoney.new(transfer.balance.to_f.abs, :usd)
              User::Commissions.get.transfer(user, refund, transfer)
            end

            flash.now[:error] = error.message
            haml :withdraw
          rescue => error
            # rollback payment unless it was already finalized in the above rescue.
            payment.reject!(error.message) if payment && !payment.finalized?

            # rollback fee deduction.
            if transfer
              refund = BigMoney.new(transfer.balance.to_f.abs, :usd)
              User::Commissions.get.transfer(user, refund, transfer)
            end

            raise error
          else
            flash[:analytics] = ['withdrawal', 'create', payment.user.id.to_s, balance.cents_usd]
            flash[:success] = '%s transfered to PayPal (%s less %s fee). ' % [net, balance, fee].map(&:to_explicit_s)
            redirect url(:profile)
          end
        end
      end
    end # Payments

    register Payments
  end # Web
end # Fundry
