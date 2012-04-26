require 'mailman'

get '/job/pledge/:id/notify-donor' do |id|
  pledge     = Fundry::Pledge.with_deleted { Fundry::Pledge.get(id) } or raise Sinatra::NotFound
  mailman    = Mailman.new
  user       = pledge.transfer.user
  to         = '"%s"<%s>' % [ user.name || user.username, user.email ]
  subject    = 'Feature "%s" has been rejected or abandoned.' % [ pledge.feature.name ]
  args       = { from: '"Fundry Mailman" <no-reply@fundry.com>', to: to, subject: subject }
  locals     = { feature: pledge.feature, balance: pledge.transfer.children.last.balance }

  failure    = mailman.send '/mail/pledge/refund', args, locals.merge(user: user), user
  env['rack.logger'].error "mailman error: #{failure.inspect}" if failure
  'ok'
end

get '/job/pledge/:id/notify-owner' do |id|
  pledge     = Fundry::Pledge.with_deleted { Fundry::Pledge.get(id) } or raise Sinatra::NotFound
  mailman    = Mailman.new
  user       = pledge.feature.project.user
  to         = '"%s"<%s>' % [ user.name || user.username, user.email ]
  subject    = 'Pledge towards "%s" has been retracted' % [ pledge.feature.name ]
  args       = { from: '"Fundry Mailman" <no-reply@fundry.com>', to: to, subject: subject }
  locals     = { donor: pledge.transfer.user, feature: pledge.feature, balance: pledge.transfer.children.last.balance }

  failure    = mailman.send '/mail/pledge/retract', args, locals.merge(user: user), user
  env['rack.logger'].error "mailman error: #{failure.inspect}" if failure
  'ok'
end

