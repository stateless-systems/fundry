require_relative '../helper'
require 'paypal'

# TODO: Fundry specific sandbox credentials.
# TODO: Top up seller account or you'll only be able to run the mass payment test while we have money in the sandbox
# account.

describe 'Paypal NVP' do
  before do
    # Sandbox.
    # XXX: Paypal sandbox credentials.
    @paypal = ::Paypal.new(
      'https://api-3t.sandbox.paypal.com/nvp',
      'XXX',
      'XXX',
      'XXX'
    )
  end

  it 'must return balance' do
    # https://cms.paypal.com/us/cgi-bin/?&cmd=_render-content&content_ID=developer/e_howto_api_nvp_r_GetBalance
    response = @paypal.perform(method: 'GetBalance')
    assert response[:ack] =~ /success/i
    assert BigMoney.new(response[:l_amt0], response[:l_currencycode0]).to_f > 0
  end

  # XXX: Email address.
  it 'must complete mass payment' do
    # N.B. Currency code must be the same as the accounts main currency.
    # https://cms.paypal.com/us/cgi-bin/?&cmd=_render-content&content_ID=developer/e_howto_api_nvp_r_MassPay
    response = @paypal.perform(
      method:       'MassPay',
      emailsubject: 'Fundry Test Withdrawal',
      currencycode: 'AUD',
      receivertype: 'EmailAddress',
      l_email0:     'XXX@XXX',
      l_amt0:       '1.00'
    )

    assert response[:ack] =~ /success/i
  end
end
