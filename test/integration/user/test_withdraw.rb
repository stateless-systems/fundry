require_relative '../helper'

describe "Paypal withdrawal" do
  before do
    Peon.flush
    @developer = new_user
    @developer.update(balance: BigMoney.new(10, :usd))
    @env = { "rack.session" => { auth: @developer.id } }
  end

  def stub_paypal_process_with message, &block
    stub   = proc {|*args| message }
    method = Paypal.instance_method(:perform)
    Paypal.send(:define_method, :perform, &stub)
    block.call
    ensure
      Paypal.class_eval { define_method :perform, method }
  end

  it "should process a successful withdrawal" do
    stub_paypal_process_with({ ack: 'success' }) do
      post '/withdraw', { withdraw: { paypal: 'test@foo.com', amount: '1.15USD' } }, @env
    end

    developer = Fundry::User.get(@developer.id)
    assert_equal 8.85, developer.balance.to_f
    assert_equal 1.15 - 1.15*0.02, developer.meta.withdrawn_balance.to_f
  end

  it "should process a failed withdrawal and cancel payment" do
    stub_paypal_process_with({ ack: 'blrag', l_longmessage0: 'piss off butthead' }) do
      post '/withdraw', { withdraw: { paypal: 'test@foo.com', amount: '1.15USD' } }, @env
    end

    developer = Fundry::User.get(@developer.id)
    assert_equal 10.0, developer.balance.to_f
    assert_equal 0,    developer.meta.withdrawn_balance.to_f
  end
end
