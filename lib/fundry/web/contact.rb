module Fundry
  class Web
    module Contact
      CONTACT_EMAIL = '"Fundry Contact" <fundry+contact@fundry.com>'

      def self.registered app

        app.get '/contact' do
          @user = authenticated? ? user : User.new
          haml :contact
        end

        app.post '/contact' do
          @subject = params['contact'].delete('subject')
          @message = params['contact'].delete('message')
          @user    = User.new(params['contact'])
          begin
            raise 'Failed captcha, try again.' unless captcha_correct?

            raise 'Missing subject.' if @subject.nil? or @subject.empty?
            raise 'Missing message.' if @message.nil? or @message.empty?
            raise 'Missing name.'    if @user.name.nil?  or @user.name.empty?
            raise 'Invalid email.'   unless !@user.email.nil? and @user.email.match(/^[^@]+@[^@]+$/)

            header = <<-TEXT
            ----------------------------------------------------

              Name:     #{@user.name}
              Username: #{@user.username || 'Not Given'}

            ----------------------------------------------------


            TEXT

            header = header.gsub(/^ +/m, '')

            text = header + @message
            html =<<-HTML
              <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
              <html lang="en">
                <body>
                  <pre>#{header}</pre>
                  #{Haml::Helpers.html_escape(@message).gsub(/\n/, "\n <br>")}
                </body>
              </html>
            HTML

            options = {
              to:      CONTACT_EMAIL,
              from:    @user.email,
              subject: @subject,
              text:    text.force_encoding('UTF-8'),
              html:    html.force_encoding('UTF-8')
            }

            PonyExpress.mail(options)
            flash[:success] = 'Message sent.'
            redirect '/'
          rescue => e
            flash.now[:error] = e.message
            haml :contact
          end
        end

      end
    end # Contact

    register Contact
  end # Web
end # Fundry
