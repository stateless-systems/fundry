require 'mailman'

get '/job/feature/acceptance/:id/donor_email' do
  acceptance = Fundry::FeatureAcceptance.get(params[:id]) or raise Sinatra::NotFound
  mailman    = Mailman.new
  user       = acceptance.pledge.transfer.user
  to         = '"%s"<%s>' % [ user.name || user.username, user.email ]
  subject    = 'Fundry: Feature "%s" has been completed.' % [ acceptance.feature.name ]
  args       = { from: '"Fundry Mailman"<no-reply@fundry.com>', to: to, subject: subject }

  failure    = mailman.send '/mail/feature/acceptance', args, { user: user, acceptance: acceptance }, user
  env['rack.logger'].error "mailman error: #{failure.inspect}" if failure
  'ok'
end
