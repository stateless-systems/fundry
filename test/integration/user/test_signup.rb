require_relative '../helper'
require 'mechanize'

describe "Profile Signup" do
  before do
    Peon.flush
    @developer = new_user
    @project   = new_project user: @developer, name: 'Test project', web: 'http://127.0.0.1:12346'
    @project.update verified: true
  end

  def pack args
    args.inject({}) do |packed, (param, value)|
      if value.kind_of?(Hash)
        value.each {|k, v| packed["#{param}[#{k}]"] = v }
      else
        packed[param] = value
      end
      packed
    end
  end


  it "should process a signup, deposit and donation in one go" do
    ipn_url, port = get_ipn_responder!

    logger  = Logger.new $stderr, 0
    myapp   = clone_app_with_logger Fundry::Web
    uri     = "https://localhost:#{port}"

    myapp.send(:define_method, :captcha_correct?) do
      true
    end

    Rack::Test::App.run myapp, socket: '/tmp/unicorn.sock', timeout: 60 do
      FileUtils.chmod 0777, '/tmp/unicorn.sock'

      Thread.new {
        mech = new_paypal_mechanize_agent
        logger.info "Finished Paypal sandbox login."

        params = {
          tc: true,
          deposit:  { amount: '40.00' },
          donation: { project_id: @project.id, amount: '20.00' },
          user:     { username: 'testbuyer', password: 'test', email: 'buyer_1276151754_per@statelesssystems.com' },
        }

        params = pack(params)

        paypal = mech.post("#{uri}/profile", params)
        logger.info "Finished signup, proceeding to deposit"

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

      sleep 0.1 while Fundry::Payment.first(state: 'new')
    end rescue nil

    payment = Fundry::Payment.first(state: 'complete')
    gross   = BigMoney.new 40, :usd
    fee     = BigMoney.new payment.messages[1]["feeamt"].to_f, :usd

    assert payment, "Payment should be complete"
    assert_equal gross-fee, payment.balance, "with a balance of %s - %s" % [ gross.to_explicit_s, fee.to_explicit_s ]

    assert_equal 20.0, Fundry::User.get(@developer.id).balance.to_f, "project got a $20 donation"
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
