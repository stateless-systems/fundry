require 'delegate'

module Sinatra
  module Pagination
    class Collection < SimpleDelegator
      attr_reader :limit, :offset, :page, :total

      def initialize collection, options = {}
        @total  = collection.size
        @limit  = options.fetch(:limit, 10).to_i
        @page   = options[:page].to_i > 0 ? options[:page].to_i : 1
        @offset = (page - 1) * limit
        super collection.slice(offset, limit) || []
      end

      def next?
        total > (offset + limit)
      end

      def previous?
        page > 1
      end
    end

    module Helpers
      def paginate collection, options = {}
        Pagination::Collection.new collection, {page: params[:page]}.update(options)
      end

      #--
      # TODO: Very very hacky url merging.
      def paginate_control collection
        previous_query = '?' + URI.escape(request.params.update('page' => collection.page - 1).map{|*a| a.join('=')}.join('&')).to_s
        previous_url   = URI.parse(request.url).merge(previous_query).to_s

        next_query = '?' + URI.escape(request.params.update('page' => collection.page + 1).map{|*a| a.join('=')}.join('&')).to_s
        next_url   = URI.parse(request.url).merge(next_query).to_s

        haml(paginate_control_haml, locals: {collection: collection, previous_url: previous_url, next_url: next_url}, layout: false)
      end

      protected
        def paginate_control_haml
          <<-'HAML'
.clearfix
.pagination
  - if collection.previous?
    %a.prev{href: previous_url} Previous
  - if collection.next?
    %a.next{href: next_url} Next
          HAML
        end
    end

    def self.registered app
      app.helpers Pagination::Helpers
    end
  end
end
