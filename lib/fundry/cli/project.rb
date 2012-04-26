module Fundry
  module Cli
    class Project
      def verify urlprefix, older_than, newer_than, logger = Logger.new($stdout, 0)
        adapter = Fundry::Project.repository.adapter
        args    = { verified: false, created_at: newer_than..older_than }
        recent  = Time.now-172800..Time.now # 2 days

        logger.info "Starting project verification #{Yajl.dump(args)}"
        Fundry::Project.all(args).each do |project|
          # do not try to verify projects which have sucessfully checked for a link or
          # widget in the last 2 days.
          if project.verifications(rank: 1..100, created_at: recent).count > 0
            logger.info "Skipping project: [#{project.id}] #{project.name} because of recent non-zero rank"
            next
          end

          begin
            project.queue_verification URI.parse("#{urlprefix}/project/#{project.slug}")
            logger.info "project #{project.id} queued for verification"
          rescue Fundry::Project::VerificationError => e
            logger.error "project #{project.id}: #{e}"
          end
        end
        logger.info "Done"
      end
    end
  end
end
