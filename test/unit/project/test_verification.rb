require_relative '../../helper'
require 'rack/test/app'
require 'open-uri'

class VerificationAnchorApp < Sinatra::Base
  get '/' do
    '<a href="http://fundry-verification.local">verify this!</a>'
  end
end

class VerificationWidgetApp < Sinatra::Base
  get '/' do
    <<-HTML
      <script type="text/javascript">
        // <![CDATA[
          Fundry.Widget("http://fundry-verification.local");
        // ]]>
      </script>
    HTML
  end
end

describe 'Project::Verification' do
  before do
    @developer = Fundry::User.create(name: 'Stephen', email: 'root@localhost', username: 'steven', password: 'steven')
    @project   = new_project(user: @developer, name: 'Verification Test', web: 'http://localhost:8081')
  end

  it 'must verify a correct vanilla anchor href' do
    Rack::Test::App.run(VerificationAnchorApp, port: '8081') do
      @project.verify! 'http://fundry-verification.local'
      assert @project.verified
    end
  end

  it 'must not verify an incorrect vanilla anchor href' do
    Rack::Test::App.run(VerificationAnchorApp, port: '8081') do
      assert_raises Fundry::Project::VerificationError do
        @project.verify! 'http://fundry-fail-verification.local'
      end
    end
  end

  it 'must verify a potential widget call' do
    Rack::Test::App.run(VerificationWidgetApp, port: '8081') do
      @project.verify! 'http://fundry-verification.local'
      assert @project.verified
    end
  end

  it 'must not verify an incorrect potential widget call' do
    Rack::Test::App.run(VerificationWidgetApp, port: '8081') do
      assert_raises Fundry::Project::VerificationError do
        @project.verify! 'http://fundry-fail-verification.local'
      end
    end
  end
end
