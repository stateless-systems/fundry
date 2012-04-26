module Fundry
  class Statistics
    attr_reader :from

    def initialize period
      @from = timestamp_at(period)
    end

    def timestamp_at value
      case value
        when '1d' then Time.now - 86400
        when '3d' then Time.now - 3*86400
        when '1w' then Time.now - 7*86400
        when '1m' then Time.now - 30*86400
        when '6m' then Time.now - 180*86400
        when '1y' then Time.now - 365*86400
        else Time.at(0)
      end
    end

    def escrow
      @escrow ||= begin
        id = User::Escrow.get.id
        sql =<<-SQL
          select * from
            (select coalesce(sum(balance_amount), 0) as balance from transfers
             where user_id = #{id} and created_at > ?) q1
            cross join
            (select coalesce(sum(balance_amount), 0) as deposits from transfers
             where user_id = #{id} and created_at > ? and balance_amount > 0) q2
            cross join
            (select coalesce(sum(balance_amount), 0) as withdrawals from transfers
             where user_id = #{id} and created_at > ? and balance_amount < 0) q3
        SQL

        User.repository.adapter.select(sql, from, from, from).first
      end
    end

    def escrow_balance
      BigMoney.new(escrow.balance, :usd)
    end

    def escrow_deposits
      BigMoney.new(escrow.deposits, :usd)
    end

    def escrow_withdrawals
      BigMoney.new(escrow.withdrawals, :usd)
    end

    def income
      @income ||= begin
        id = User::Commissions.get.id
        sql =<<-SQL
          select coalesce(sum(balance_amount),0) as balance from transfers where created_at > ? and user_id = #{id}
        SQL
        BigMoney.new(User.repository.adapter.select(sql, from).first, :usd)
      end
    end

    def users
      User.all(:created_at.gte => from).count
    end

    def projects
      Project.all(:created_at.gte => from).count
    end

    def features_created
      Feature.all(:created_at.gte => from).count
    end

    def features_completed
      Feature.all(:created_at.gte => from, state: "complete").count
    end

    def pledges
      Pledge.all(:created_at.gte => from).count
    end

    def pledged
      BigMoney.new(-(Pledge.all(:created_at.gte => from).transfers.sum(:balance_amount) || 0), :usd)
    end

    def funded
      BigMoney.new(
        -(Feature.all(:updated_at.gte => from, state: "complete").pledges.transfers.sum(:balance_amount) || 0),
        :usd
      )
    end

    def abuse_reports
      sql =<<-SQL
        select p.id, p.name, a.complaints from projects p join
        (select project_id, count(*) as complaints from abuse_reports group by project_id) a on (p.id = a.project_id)
        where p.deleted_at is null
      SQL
      Project.repository.adapter.select(sql)
    end
  end
end
