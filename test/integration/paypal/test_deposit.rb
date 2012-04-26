require_relative '../helper'
require 'mechanize'

describe "Paypal Deposit and Withdrawl" do
  before do
    Peon.flush
    # XXX: Email address.
    @donor     = new_user balance: BigMoney.new(1.15, :usd), email: "XXX@XXX"
    @env       = { "rack.session" => { auth: @donor.id } }
  end


  it "should process completed paypal deposits" do
    ipn_url, port = get_ipn_responder!

    logger  = Logger.new $stderr, 0
    myapp   = clone_app_with_logger Fundry::Web, env: @env
    uri     = "https://localhost:#{port}/deposit"

    Rack::Test::App.run myapp, socket: '/tmp/unicorn.sock', timeout: 60 do
      FileUtils.chmod 0777, '/tmp/unicorn.sock'

      Thread.new {
        mech = new_paypal_mechanize_agent
        logger.info "Finished Paypal sandbox login."

        paypal = mech.get(uri).form_with(name: 'deposit') do |form|
          form["deposit[amount]"] = '5.00'
        end.submit
        logger.info "Finished deposit at /deposit"

        paypal_confirm = paypal.form_with(name: 'billing') do |form|
          form.delete_field! 'login.x'
          form.add_field! 'login.x', 'Log In'
          form.login_password = '276151728'
        end.submit
        logger.info "Finished Paypal buyer login."

        response = paypal_confirm.form_with(name: 'main') do |form|
          form.delete_field! 'continue.x'
          form.add_field! 'continue.x', 'Pay Now'
        end.submit
        logger.info "Finished Paypal payment confirmation."
      }.join

      sleep 0.1 while Fundry::Payment.first(user_id: @donor.id, state: 'new')
      # TODO We need to check if we get IPN message back from paypal, but that
      #      seems to be quite unreliable at the moment.
    end rescue nil

    payment = Fundry::Payment.first(user_id: @donor.id, state: 'complete')

    gross   = BigMoney.new 5, :usd
    fee     = BigMoney.new payment.messages[1]["feeamt"].to_f, :usd

    assert payment, "Payment should be complete"
    assert_equal gross-fee, payment.balance, "with a balance of %s - %s" % [ gross.to_explicit_s, fee.to_explicit_s ]
  end

  private
  def get_ipn_responder!
    ipn_url = ENV['PAYPAL_IPN_URL'] || ''
    port    = if match = ipn_url.match(/:(\d+)/)
      match.captures.first
    else
      nil
    end

    if port
      return [ ipn_url, port ]
    else
      $stderr.puts <<-MSG
        [ WARNING ] You need to set PAYPAL_IPN_URL env to point to Fundry Paypal IPN receiver url with an
                    explicit port number that is accessible externally from Paypal.

                    e.g. PAYPAL_IPN_URL=https://dev.office.statelessystems.com:8080/paypal/ipn
      MSG

      skip
    end
  end
end
