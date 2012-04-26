post '/job/project/:id/verify' do |id|
  project = Fundry::Project.get(id) or raise Sinatra::NotFound
  halt 200, 'ok' if project.verified

  uri = params['uri'] or raise "Unable to verify without widget or project uri"

  begin
    project.verify! uri
  rescue Fundry::Project::VerificationError => error
    if project.verification_timeout?
      project.schedule_work :"verify-reminder" if project.needs_verification_reminder?
      halt 500, {}, error.message
    else
      halt 503, { "Retry-After" => "300" }, error.message
    end
  end
  'ok'
end

get '/job/project/:id/verify-reminder' do |id|
  project = Fundry::Project.get(id) or raise Sinatra::NotFound
  halt 200, 'ok' if project.verified

  mailman     = Mailman.new
  user        = project.user
  to          = '"%s"<%s>' % [ user.name || user.username, user.email ]
  subject     = 'Project "%s" has not been verified yet' % [ project.name ]
  args        = { from: '"Fundry Mailman" <no-reply@fundry.com>', to: to, subject: subject }
  locals      = { project: project, user: user, unsubscribe: unsubscribe_url(user, :reminders) }

  failure     = mailman.send '/mail/project/verification_reminder', args, locals, user
  env['rack.logger'].error "mailman error: #{failure.inspect}" if failure
  'ok'
end
