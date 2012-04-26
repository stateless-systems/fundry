# TODO Figure out where this should be - this is web service but not really background
#      worker.
post '/paypal/ipn' do

  request.body.rewind
  message  = request.body.read

  # NOTE It's transactionid in the first response from Paypal and txn_id later - go figure.
  txn_id   = params['txn_id']
  payment  = Fundry::Payment.first(transaction_id: txn_id) or raise Sinatra::NotFound

  if paypal.validate message
    env['rack.logger'].info "[ PAYPAL ] - VERIFIED payment with transaction id: #{txn_id}"
    paypal.process_ipn(payment, params)
  else
    env['rack.logger'].warn "[ PAYPAL ] - INVALID  payment with transaction id: #{txn_id}"
  end

  'ok'
end
