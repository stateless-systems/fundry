require 'mailman'
module Fundry
  module Cli
    class Check
      def initialize adapter
        @adapter = adapter
      end

      def transfers
        # Find all root transfer ids for which the balance amounts don't add up to zero.
        result = @adapter.select <<-SQL
          WITH RECURSIVE checksum_tb(root, created, id, parent_id, balance) AS (
            SELECT id AS root, created_at AS created, id, parent_id, balance_amount AS balance
            FROM transfers WHERE parent_id IS NULL
            UNION ALL SELECT trc.root, trc.created, t.id, t.parent_id, t.balance_amount AS balance
                      FROM transfers t JOIN checksum_tb trc ON (t.parent_id = trc.id)
          ) SELECT root AS id, created, SUM(balance) AS balance FROM checksum_tb
            GROUP by root, created HAVING SUM(balance) != 0
        SQL

        # Uh oh, something's fishy.
        if result.length > 0
          bad     = result.map {|r| "ID: %-8d DATE: %s BALANCE: %.2f" % [ r.id, r.created, r.balance ] }.join("<br/>")
          mailman = Mailman.new
          args    = {
            from:    '"Fundry Mailman (Alert)"<no-reply@fundry.com>',
            to:      'root@localhost',
            subject: "Whoops, pledges don't add up."
          }
          mailman.send '/mail/alerts/accounting/pledge', args, {bad: bad}
        end
      end

      def balances
        result = @adapter.select <<-SQL
          select * from (
            select u.id, u.username, u.balance_amount as balance, sum(coalesce(t.balance_amount,0)) as acc
            from users u left join transfers t on (u.id = t.user_id) where u.id > 5
            group by u.id, username, balance order by u.id
          ) bl where acc != balance
        SQL

        if result.length > 0
          bad     = result.map {|r| "ID: %-8d BALANCE: %.2f TRANSFERS: %.2f USER: %s" % [r.id, r.balance, r.acc, r.username]}
          mailman = Mailman.new
          args    = {
            from:    '"Fundry Mailman (Alert)"<no-reply@fundry.com>',
            to:      'root@localhost',
            subject: "Balance and Transfers don't add up."
          }
          mailman.send '/mail/alerts/accounting/balance', args, {bad: bad.join('<br/>')}
        end
      end

    end # Check
  end # Cli
end # Fundry
