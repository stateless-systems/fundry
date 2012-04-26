require 'fundry'

#--
# TODO: Do something about migration scripts!
module Fundry
  module Migrations
    def self.auto_migrate!
      DataMapper.auto_migrate!
      users
    end

    def self.auto_upgrade!
      DataMapper.auto_upgrade!
    end

    #--
    # TODO: User groups.
    def self.users
      password = 'a;e8fu9p8as'
      User.create(password: password, name: 'Fundry',             username: User::Site::USERNAME,        email: 'site+fundry@fundry.com')
      User.create(password: password, name: 'Fundry Commissions', username: User::Commissions::USERNAME, email: 'commissions+fundry@fundry.com')
      User.create(password: password, name: 'Fundry Escrow',      username: User::Escrow::USERNAME,      email: 'escrow+fundry@fundry.com')
      User.create(password: password, name: 'Fundry PayPal',      username: User::Paypal::USERNAME,      email: 'paypal+fundry@fundry.com')
      User.create(password: password, name: 'Anonymous',          username: User::Anonymous::USERNAME,   email: 'anon+fundry@fundry.com')

      fundry = Project.create(
        user:    User::Site.get,
        name:    'Fundry',
        summary: 'The Fundry project!',
        detail:  'The Fundry project!',
        twitter: '@fundry',
        web:     'http://fundry.com',
      )
      fundry.update(verified: true)
    end
  end

  def self.auto_migrate!
    Migrations.auto_migrate!
  end

  def self.auto_upgrade!
    Migrations.auto_upgrade!
  end
end

