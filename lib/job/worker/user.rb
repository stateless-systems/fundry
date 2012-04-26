require 'mailman'

get '/job/user/:id/recover' do
  user    = Fundry::User.get(params[:id]) or raise Sinatra::NotFound
  mailman = Mailman.new
  to      = '"%s"<%s>' % [ user.name || user.username, user.email ]
  subject = "Fundry: Profile recovery."
  args    = { from: '"Fundry Mailman"<no-reply@fundry.com>', to: user.email, subject: subject }

  failure = mailman.send '/mail/user/recover', args, { user: user }, user
  env['rack.logger'].error "mailman error: #{failure.inspect}" if failure
  'ok'
end

get '/job/user/:id/suspend-email' do
  user    = Fundry::User.get(params[:id]) or raise Sinatra::NotFound
  mailman = Mailman.new
  to      = '"%s"<%s>' % [ user.name || user.username, user.email ]
  subject = "Fundry: Profile suspended."
  args    = { from: '"Fundry Mailman"<no-reply@fundry.com>', to: user.email, subject: subject }

  failure = mailman.send '/mail/user/suspended', args, { user: user }, user
  env['rack.logger'].error "mailman error: #{failure.inspect}" if failure
  'ok'
end

get '/job/user/:id/unsuspend-email' do
  user    = Fundry::User.get(params[:id]) or raise Sinatra::NotFound
  mailman = Mailman.new
  to      = '"%s"<%s>' % [ user.name || user.username, user.email ]
  subject = "Fundry: Profile unsuspended."
  args    = { from: '"Fundry Mailman"<no-reply@fundry.com>', to: user.email, subject: subject }

  failure = mailman.send '/mail/user/unsuspended', args, { user: user }, user
  env['rack.logger'].error "mailman error: #{failure.inspect}" if failure
  'ok'
end
