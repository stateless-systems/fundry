# encoding: utf-8

module Fundry
  module Cli
    module DevelopmentData
      #--
      # Forgive the length of this. It's more useful than the random generated stuff that we did have.
      def self.create
        #--
        # Users.
        puts 'Creating users...'
        shane = Fundry::User.create(
          bio:      'Haxor!',
          email:    'shane.hanna@gmail.com',
          name:     'Shane Hanna',
          twitter:  '@shanehanna',
          password: 'test',
          username: 'shane',
          web:      'http://shanehanna.org',
        )
        shane.deposit(BigMoney.new('1.45', :usd)).complete!
        shane.deposit(BigMoney.new('12.45', :usd)).complete!
        shane.deposit(BigMoney.new('123.45', :usd)).complete!
        shane.withdraw(BigMoney.new('8.25', :usd)).complete!
        shane.deposit(BigMoney.new('1234.45', :usd)).complete!
        shane.withdraw(BigMoney.new('89.25', :usd)).complete!
        shane.roles.create(name: 'admin')

        barney = Fundry::User.create(
          bio:      'Haxor!',
          email:    'deepfryed@gmail.com',
          name:     %q{Bharanee 'Barney' Rathnasabapathy},
          twitter:  '@deepfryed',
          password: 'test',
          username: 'deepfryed',
        )
        barney.deposit(BigMoney.new('1.45', :usd)).complete!
        barney.deposit(BigMoney.new('12.45', :usd)).complete!
        barney.deposit(BigMoney.new('123.45', :usd)).complete!
        barney.withdraw(BigMoney.new('8.25', :usd)).complete!
        barney.deposit(BigMoney.new('1234.45', :usd)).complete!
        barney.withdraw(BigMoney.new('89.25', :usd)).complete!
        barney.roles.create(name: 'admin')

        stateless = Fundry::User.create(
          bio:      %q{
# Stateless Systems
Hi there.
We're a little web startup workshop operating out of Melbourne, Australia.
We love the web and love building stuff for it.
Over 14 million visitors a month enjoy our sites.
We hope you do too...
          },
          email:    'enquiries@statelesssystems.com',
          name:     'Stateless Systems',
          password: 'test',
          username: 'stateless',
          web:      'http://statelesssystems.com'
        )
        stateless.deposit(BigMoney.new('1.45', :usd)).complete!
        stateless.deposit(BigMoney.new('12.45', :usd)).complete!
        stateless.deposit(BigMoney.new('123.45', :usd)).complete!
        stateless.withdraw(BigMoney.new('8.25', :usd)).complete!
        stateless.deposit(BigMoney.new('1234.45', :usd)).complete!
        stateless.withdraw(BigMoney.new('89.25', :usd)).complete!

        30.times do |n|
          message=<<-TEXT
            Dear Stateless Systems,

            Your account has been unsuspended. All your projects should be accessible and
            you should be able to use Fundry as usual.

            Thanks for your patience and understanding.

            Sincerely,

            The Fundry Geek Squad

            Fundry.com | Updates: http://twitter.com/fundrydotcom
          TEXT
          stateless.emails.create(
            to: stateless.email,
            from: 'fundry@fundry.com',
            subject: "test email #{n}",
            message: message.gsub(/^ */m, '') + (n%2 == 0 ? "filler content .......... \n\n "*20 : '')
          )
        end

        arthurtons = []
        %w{apple benny cherry dick egbert faye gilbert hugh indigo jörg kenneth}.each do |name|
          arthurtons << Fundry::User.create(
            email:    "#{name}@arthurton.local",
            name:     "#{name.capitalize} Arthurton",
            password: 'test',
            username: name
          )
          arthurtons.last.deposit(BigMoney.new('123.45', :usd)).complete!
        end

        constance = Fundry::User.create(
          bio:      %q{
Constance E. Little, one of the most prolific writers of letters to the editor of The Age across five decades, has died in Melbourne, aged 89.

A vociferous opponent of war, an early campaigner against global warming and an advocate of social justice, Ms Little was diligently posting her missives to newspapers long before there were internet forums to publicly spout opinions at the click of a button.

"Constance E. Little was a stalwart in The Age letters pages for decades and many readers felt they knew her personally, such was her ability to write pithily on a wide range of topics," The Age opinion editor, Roslyn Guy, said.
          },
          email:    'enquiries@constance-e-little.local',
          name:     'Constance Esmeralda Tegan Anne Bell Emma Carol Little',
          password: 'test',
          username: 'constance-e-little',
          web:      'http://www.theage.com.au/national/last-writes-for-letters-of-constance-e-little-20090615-carj.html'
        )
        constance.deposit(BigMoney.new('1.45', :usd)).complete!
        constance.deposit(BigMoney.new('12.45', :usd)).complete!
        constance.deposit(BigMoney.new('123.45', :usd)).complete!
        constance.withdraw(BigMoney.new('8.25', :usd)).complete!
        constance.deposit(BigMoney.new('1234.45', :usd)).complete!
        constance.withdraw(BigMoney.new('89.25', :usd)).complete!

        #--
        # Projects.
        puts 'Creating projects...'
        bugmenot = Fundry::Project.create(
          detail:  %q{Find and share logins for websites that force you to register.},
          name:    'BugMeNot',
          summary: %q{Bypass 'compulsory' registration.},
          twitter: '@bugmenot',
          user:    stateless,
          web:     'http://bugmenot.com',
        )
        bugmenot.update(verified: true)

        rmn = Fundry::Project.create(
          detail:  %q{Coupon codes and discounts for 65,000 online stores!},
          name:    'RetailMeNot',
          summary: %q{Coupon codes and discounts for 65,000 online stores!},
          twitter: '@retailmenot',
          user:    stateless,
          web:     'http://retailmenot.com',
        )
        rmn.update(verified: true)

        cushy = Fundry::Project.create(
          detail:  %q{
# CushyCMS

## Web Designers:
* Allow clients to safely edit content
* No software to install, no programming required
* Takes just a few minutes to setup
* Produces standards compliant, search engine friendly content
* Define exactly which parts of the page can be changed

## Content Editors:
* Super. Easy. To. Use.
          },
          name:    'CushyCMS',
          summary: %q{Finally, a free and truly simple CMS},
          user:    stateless,
          web:     'http://cushycms.com',
        )
        cushy.update(verified: true)

        oursignal = Fundry::Project.create(
          detail:  %q{
OurSignal.com looks at currently popular items on the social news sites of your choosing and mashes them all together. The idea is to allow users (you especially) to get a rapid overview of the latest breaking headlines that match specific interests.

* Create your very own customized oursignal and share it with others
* Add/remove news sources e.g. Mashable, ReadWriteWeb, TechCrunch
* Use sliders to assign relative importance to each news source
* Pick from a range of 'visualizations' to suit your reading style (bigger links are more important, hotter colors are items on the rise)
* If multiple sources mention the same url (e.g. http://trendsmap.com) then those items are combined and considered more important
* Access to RSS/XML/JSON output for developer mashups

Please let us know if you discover any bugs or have any suggestions.
          },
          name:    'OurSignal',
          summary: %q{Current popular items on social news sites.},
          twitter: '@oursignal',
          user:    stateless,
          web:     'http://oursignal.com',
        )
        oursignal.update(verified: true)

        tm = Fundry::Project.create(
          detail:  %q{Trendsmap.com is a real-time mapping of Twitter trends across the world. See what the global, collective mass of humanity are discussing right now.},
          name:    'Trendsmap',
          summary: %q{Real-time local twitter trends.},
          twitter: '@trendsmap',
          user:    stateless,
          web:     'http://trendsmap.com',
        )
        tm.update(verified: true)

        bmp = Fundry::Project.create(
          detail:  %q{
# A new way to find low prices...
* Find the best price you can online
* Visit beatmyprice.com
* Enter the details
* See if someone has found it cheaper elsewhere
* Save! (otherwise your price become the one to beat)
          },
          name:    'BeatMyPrice',
          summary: %q{A new way to find low prices.},
          twitter: '@beatmywife',
          user:    stateless,
          web:     'http://beatmyprice.com',
        )
        bmp.update(verified: false)

        metauri = Fundry::Project.create(
          detail:  %q{MetaURI is a free service that follows all redirects for a given URI and then gives you back meta information about that final URI in a variety of formats.},
          name:    'MetaURI',
          summary: %q{URI meta information service.},
          twitter: '@metauri',
          user:    stateless,
          web:     'http://metauri.com',
        )
        metauri.update(verified: false)

        bitsnare = Fundry::Project.create(
          detail:  %q{Bitsnare eliminates repeated searches by periodically querying public APIs on your behalf for recurring or unreleased torrents.},
          name:    'Bitsnare',
          summary: %q{Scheduled torrent query service},
          twitter: '@bitsnare',
          user:    shane,
          web:     'http://bitsnare.com',
        )
        bitsnare.update(verified: false)

        swift = Fundry::Project.create(
          detail:  %q{
# A rational Ruby rudimentary object relational mapper.

## Features
* Multiple databases.
* Prepared statements.
* Bind values.
* Transactions and named save points.
* EventMachine asynchronous interface.
* Migrations.

## Performance
Swift prefers performance when it doesn’t compromise the Ruby-ish interface. It’s unfair to compare Swift to DataMapper and ActiveRecord which suffer under the weight of support for many more databases and legacy/alternative Ruby implementations. That said obviously if Swift were slower it would be redundant so benchmark code does exist in github.com/shanna/swift/tree/master/benchmarks
          },
          name:    'Swift ORM',
          summary: %q{A rational Ruby rudimentary object relational mapper.},
          user:    shane,
          web:     'http://github.com/shanna/swift',
        )
        swift.update(verified: false)

        bitsnare = Fundry::Project.create(
          detail:  %q{Bitsnare eliminates repeated searches by periodically querying public APIs on your behalf for recurring or unreleased torrents.},
          name:    'Bitsnare',
          summary: %q{Scheduled torrent query service},
          twitter: '@bitsnare',
          user:    shane,
          web:     'http://bitsnare.com',
        )
        bitsnare.update(verified: true)

        dbicpp = Fundry::Project.create(
          detail:  %q{
dbic++ is a Perl DBI style database client library abstraction which comes with support for the following databases.
* PostgreSQL >= 8.0
* MySQL >= 5.0

## Main Features
* Simple API to maximize cross database support.
* Supports nested transactions.
* Auto reconnect, re-prepare & execute statements again unless inside a transaction.
* Provides APIs for async queries and a simple reactor API built on libevent.
          },
          name:    'DBI C++',
          summary: %q{dbic++ is a Perl DBI style database client library abstraction for C++.},
          user:    barney,
          web:     'http://github.com/deepfryed/dbicpp',
        )
        dbicpp.update(verified: false)
        dbicpp.verifications.create(rank: 1)

        letters_by_constance = Fundry::Project.create(
          detail:  %q{
A vociferous opponent of war, an early campaigner against global warming and an advocate of social justice, Ms Little was diligently posting her missives to newspapers long before there were internet forums to publicly spout opinions at the click of a button.
          },
          name:    %q{A very long anthology of letters by Constance E. Little.},
          summary: %q{A very long anthology of letters by Constance E. Little. Read decades of letter to The Age on a wide range of topics.},
          user:    constance,
          web:     'http://www.theage.com.au/national/last-writes-for-letters-of-constance-e-little-20090615-carj.html',
        )
        letters_by_constance.update(verified: true)

        #--
        # Donate.
        puts 'Creating donations...'

        sample_messages = [
          'A great news aggregator, keep up the good work. Like to see more features.',
          'I like how you use the treemap view to bring attention to hot trends on my RSS.',
          'Its simple, easy on my eyes. I would like a way to customize the color schemes though :)'
        ]

        arthurtons.each_with_index do |arthurton, idx|
          arthurton.donate oursignal, BigMoney.new('6.50', :usd), false, sample_messages[idx%3]
        end

        shane.donate  dbicpp,               BigMoney.new('1.05', :usd), false,
                      'dbic++ is a great database library. Saved me a pile of money on memory and CPU'

        shane.donate  rmn,                  BigMoney.new('1.00', :usd), false,
                      'Great coupon site. I always check retailmenot.com before buying anything.'

        shane.donate  oursignal,            BigMoney.new('2.00', :usd), false,
                      'A lovely aggregator and lets me read the juiciest stories in my own time.'

        shane.donate  letters_by_constance, BigMoney.new('3.00', :usd), false,
                      'Constance was a great writer, I wish more of her letters are published online.'

        barney.donate rmn,                  BigMoney.new('1.05', :usd)
        barney.donate swift,                BigMoney.new('1.05', :usd), true,
                      'Swift is an awesome ORM. Lightweight and functional - exactly what I need!'

        #--
        # Features.
        puts 'Creating features...'
        features = []
        features << oursignal.features.create(
          name:   %q{Let me delete links I don't care about},
          detail: %q{
Let me delete links that I don't care about.

You could probably use some form of machine learning to start filtering out news stories that I don't want to see after I have deleted a few links.
      }
        )

        features << oursignal.features.create(
          name:   'Get acquired by google.',
          detail: %q{Why not?}
        )

        features << oursignal.features.create(
          name:   'Provide voting links.',
          detail: %q{
So that I can vote for the news article from oursignal.com itself, without having to open it in Digg or Reddit.
Also oursignal.com can remember/figure out which articles I voted and may be show an icon on those articles indicating my vote.
          }
        )

        features << oursignal.features.create(
          name:   'Make the number of articles configurable',
          detail: %q{
Allow a user to choose how many links to display on the page.

Great service by the way, love it.
          }
        )

        features << oursignal.features.create(
          name:   'Provide voting links.',
          detail: %q{
So that I can vote for the news article from oursignal.com itself, without having to open it in Digg or Reddit.
Also oursignal.com can remember/figure out which articles I voted and may be show an icon on those articles indicating my vote.
          }
        )

        features << oursignal.features.create(
          name:   %q{Hide stories I've clicked on},
          detail: 'As apposed to teh faded strikethrough effect'
        )

        features << oursignal.features.create(
          name:   'The old version is better',
          detail: %q{
I don't like the new version of oursignal.

Keep it simple.
          }
        )

        features << oursignal.features.create(
          name:   'Allow me to get rid of old or unwanted news',
          detail: %q{Simply put other than just hiding links I've been to sometimes I don't wanna visit a link but I don't want to see it either.}
        )

        features << oursignal.features.create(
          name:   %q{Make browsing through old links easier},
          detail: %q{I mean, I can read less than 40 links (sounds like a lot but I'd like more)}
        )

        features << oursignal.features.create(
          name:   'The old version is better',
          detail: %q{keep this up forever}
        )

        features << oursignal.features.create(
          name:   'Make a mobile version, suitable for small screens',
          detail: %q{I'm an Apple fanboy and I'd like to browse oursignal while I sit on the tram in my trendy tight jeans.}
        )

        features << letters_by_constance.features.create(
          name:   %q{This is a bunch of words rougly the length of the feature title},
          detail: %q{I'm an Apple fanboy and I'd like to browse oursignal while I sit on the tram in my trendy tight jeans.}
        )

        # Pledge.
        puts 'Creating pledges...'
        features.each do |feature|
          next if feature.id == 12
          shane.pledge  feature, BigMoney.new('1.10', :usd)
          barney.pledge feature, BigMoney.new('2.00', :usd)
          arthurtons.each do |arthurton|
            arthurton.pledge feature, BigMoney.new((1 + rand(4)).to_s, :usd)
          end
        end

        # Create a completed feature.
        Feature.get(11).feature_states.create(status: 'complete')

        # and a rejected one.
        Feature.get(12).feature_states.create(status: 'rejected')
      end

    end # DevelopmentData
  end # Cli
end # Fundry
