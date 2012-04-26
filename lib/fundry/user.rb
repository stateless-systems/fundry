require 'uri'
require 'uri/sanitize'
require 'cgi'
require 'digest/md5'
require 'digest/sha1'
require 'fundry/transfer'
require 'fundry/event'
require 'fundry/user_meta'
require 'fundry/user/donate'
require 'fundry/user/payment'
require 'fundry/user/pledge'
require 'fundry/user/transfer'

# special users.
require 'fundry/user/commissions'
require 'fundry/user/escrow'
require 'fundry/user/paypal'
require 'fundry/user/site'
require 'fundry/user/anonymous'

module Fundry

  # ==== Notes
  # Never update the balance directly. I can't make it private because of the update() calls inside
  # Fundry::User::Transfer.
  class User
    include DataMapper::Resource
    property   :id,             Serial
    property   :bio,            Text
    property   :name,           String,  length: 250
    property   :email,          String,  length: 250, required: true
    property   :username,       String,  length: (2..20), required: true, index: true
    property   :password,       String,  length: 40, required: true
    property   :password_reset, String,  length: 40
    property   :twitter,        String,  length: 15
    property   :web,            String,  length: 250
    property   :currency,       String,  length: 3, default: 'USD'
    property   :gravatar,       String,  length: 250

    # last login client_ip.
    property   :client_ip,      String,   lazy: true
    property   :last_login_at,  DateTime, lazy: true

    money      :balance,                 required: true, precision: 15, scale: 5, default: BigMoney.new(0, :usd)
    timestamps :at

    property   :suspended_at,   DateTime
    property   :deactivated_at, DateTime

    has 1, :subscription
    has 1, :meta,      Fundry::UserMeta, constraint: :destroy!
    has n, :events
    has n, :payments,  Fundry::Payment,  constraint: :destroy!
    has n, :projects,                    constraint: :destroy!
    has n, :transfers, Fundry::Transfer, constraint: :destroy!
    has n, :comments
    has n, :roles,         constraint: :destroy!
    has n, :abuse_reports, constraint: :destroy!
    has n, :emails,        constraint: :destroy!

    validates_uniqueness_of :username, :email
    validates_with_method   :web,      method: :validate_web
    validates_with_method   :username, method: :validate_username
    validates_with_method   :email,    method: :validate_email

    after :create do
      Fundry::UserMeta.create(user_id: id) # Avoid user.meta.first_or_create all over the joint.
      Fundry::Event::User::Create.create(
        user_id: id,
        detail:  {user: {id: id, name: name}}
      )
      Fundry::Subscription.create(user_id: id) unless subscription
    end

    # Just in case you don't validate the touched hook still needs to run.
    before :save do
      self.twitter  = twitter_username(twitter)  if attribute_dirty?(:twitter)
      self.password = digest_password(password)  if attribute_dirty?(:password)
      self.gravatar = gravatar_digest(email)     if attribute_dirty?(:email)
      self.name     = username                   if self.name.nil? or self.name.match(/^\s*$/)
    end

    #--
    # username is unique and is a cheaper lookup.
    def group? type
      case type
        when :gateway
          [Paypal::USERNAME].include?(username)
        when :system
          [Paypal::USERNAME, Escrow::USERNAME, Commissions::USERNAME].include?(username)
        when :fundry
          [Paypal::USERNAME, Escrow::USERNAME, Commissions::USERNAME, Anonymous::USERNAME].include?(username)
        else false
      end
    end

    def admin?
      roles(name: 'admin').count > 0
    end

    def active?
      !deactivated_at && !suspended_at
    end

    def suspended?
      !!suspended_at
    end

    def suspend!
      raise '+user+ is already suspended' if suspended?
      update(suspended_at: Time.now)
      schedule_work :"suspend-email"
    end

    def unsuspend!
      raise '+user+ is already unsuspended' unless suspended?
      update(suspended_at: nil)
      schedule_work :"unsuspend-email"
    end

    def want_updates?
      subscription && subscription.updates?
    end

    def want_reminders?
      subscription && subscription.reminders?
    end

    # TODO highly inefficient - fix it or cache it for a short duration
    def deactivation_errors
      errors              = {}
      acceptance_complete = { state: %w(accepted rejected) }

      # pledges by this user
      awaiting = Pledge.all(transfer: {user_id: id}, feature: {state: 'complete'}, acceptance: {state: 'pending'})
      complete = Pledge.all(transfer: {user_id: id}, feature: {state: 'complete'}, acceptance: acceptance_complete)
      pledges  = Pledge.all(transfer: {user_id: id}) - awaiting - complete

      # pledges to this user
      ids = repository.adapter.select <<-SQL
        select p.id from projects p
                    join features f on (f.project_id = p.id)
                    join pledges pl on (f.id = pl.feature_id)
                    left join feature_acceptances fa on (f.id = fa.feature_id)
                    where p.user_id = #{id} and (fa.state is null or fa.state = 'pending')
      SQL

      projects = Project.all(id: ids)

      errors[:awaiting] = ['You have made pledges that are awaiting approval.', awaiting]  unless awaiting.empty?
      errors[:pledges]  = ['You have pledges that need to be retracted first.', pledges]   unless pledges.empty?
      errors[:projects] = ['You have projects with active pledges by others.', projects]   unless projects.empty?
      errors[:balance]  = ['Please withdraw your balance into a paypal account.', balance] if balance_amount > 0

      errors
    end

    def slug
      CGI.escape(username)
    end

    #--
    # TODO: Can I define this as a has n, with scope?
    def pledges
      Pledge.all(Pledge.transfer.user.id => self.id)
    end

    #--
    # TODO: Can I define this as a has n, with scope?
    def donations
      Donation.all(Donation.transfer.user.id => self.id)
    end

    def self.find_by_identifier identifier
      identifier =~ /@/ ? first(email: identifier) : first(username: identifier)
    end

    # ==== Paramaters
    # identifier<String>:: Username or email.
    # password<String>::   Unencrypted password.
    def self.authenticate identifier, password
      return unless user = find_by_identifier(identifier)
      new(username: user.username, password: password).authenticate
    end

    def authenticate
      self.class.first(username: username, password: digest_password(password))
    end

    def self.recover identifier
      return unless user = find_by_identifier(identifier)
      user.update(password_reset: Digest::SHA1.hexdigest('some salt' + user.username + DateTime.now.to_s))
      user.schedule_work :recover
      user
    end

    def worker_path
      '/job/user'
    end

    def gravatar_url size, ssl = false
      base = ssl ? 'https://secure.gravatar.com' : 'http://gravatar.com'
      base + '/avatar/' + gravatar + "?s=#{size}"
    end

    def digest_password password
      Digest::SHA1.hexdigest('some salt' + password.to_s)
    end

    protected
      def validate_web
        begin
          # NOTE model.properties[:web].required? is cleaner but slower.
          return true if web.nil? or web.empty?
          sanitized = URI.sanitize(web.to_s)
          sanitized.is_a?(URI::HTTP) || [false, 'Web must be http(s) scheme.']
          %r{http(s)?://[^.]+\.[^.]+}.match(sanitized.to_s) || [false, %q{Web doesn't look like a valid URI.}]
        rescue => error
          return [false, error.message]
        end
        true
      end

      def validate_username
        if username =~ %r/^\p{Alpha}[\p{Alnum}_\-]+$/ui
          true
        else
          [false, "Username must begin with a letter followed by letters, numbers, '_' or '-'."]
        end
      end

      def validate_email
        if email =~ %r/^[^@]+\@[^.]+/ui
          true
        else
          [false, %q{Email address '%s' doesn't look valid.} % email]
        end
      end

      def gravatar_digest email
        Digest::MD5.hexdigest(email.to_s.downcase.strip)
      end

      def twitter_username string
        unless string.nil?
          twitname = URI.parse(string).path.split('/').last rescue string.split('/').last
          twitname ? twitname.strip.sub(/^\s*@\s*/, '') : nil
        end
      end
  end # User
end # Fundry

