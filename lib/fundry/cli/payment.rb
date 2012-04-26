require 'logger'
require 'file/pid'
module Fundry
  module Cli
    class Payment
      def process_features options={}

        id       = options[:id]
        created  = options[:cutoff] || Time.now-86400*7

        count    = 0
        lockfile = "/tmp/fundry.payment.feature.pid"
        lock     = File::Pid.new(lockfile, $$)
        adapter  = Fundry::Feature.repository.adapter
        logger   = options[:logger] || Logger.new($stderr, 0)

        lock.run do

          logger.info "Fetching all features that need processing"
          Fundry::Feature.all(id: id ? id : adapter.select(sql, created)).each do |feature|
            count += 1
            logger.info "Processing feature - #{feature.name}"
            begin
              feature.finalize! logger
            rescue => e
              logger.error "#{e}"
            end
            logger.info "Done"
          end
          logger.info "Processed #{count} features"
        end
      end

      private

      def sql
        sql = <<-SQL
          select distinct f.id from users u join projects p on (u.id = p.user_id)
                                            join features f on (p.id = f.project_id)
                                            join feature_acceptances fa on (f.id = fa.feature_id)
          where u.suspended_at is null and u.deactivated_at is null and fa.open is true and fa.created_at <= ?
        SQL
      end
    end # Payment
  end # Cli
end # Fundry
