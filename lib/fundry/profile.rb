module Fundry
  module Profile
    def self.create params, human = false
      errors = human ? [] : [ "Incorrect CAPTCHA, please try again." ]
      errors << 'You have not accepted the Terms and Conditions' unless params[:tc]
      user   = User.new(params[:user])

      errors += user.errors.values.flatten.map(&:to_s) unless user.valid?
      errors += validate(params)

      if errors.empty?
        user.save
        errors += user.errors.values.flatten.map(&:to_s) unless user.saved?
      end

      [user, errors]
    end

    def self.validate params
      errors  = []
      errors += validate_monies(params) if params[:deposit]

      if feature = params['feature']
        %w(name detail).each do |key|
          errors << "Feature: #{key} should not be empty" if feature.key?(key) and feature[key].empty?
        end
      end

      if params.key?('project')
        project = Project.new(params['project'])
        unless project.valid?
          # the project is created via a post internal redirect. user validations are done prior to that
          # and we dont need to check here.
          project.errors.delete(:user_id)
          errors += project.errors.values.flatten.map(&:to_s)
        end
      end

      errors
    end

    def self.validate_monies params
      fee, cut = Payment.paypal_fees
      deposit  = parse_money(params['deposit']['amount']) {|e| errors << "Deposit: #{e}"}
      errors   = []

      errors << "Deposit: must be atleast 0.01 USD" if deposit <= BigMoney::ONE_CENT

      if params['donation']
        donation = parse_money(params['donation']['amount']) {|e| errors << "Donation: #{e}"}
        errors << "Donation: must be atleast 0.01 USD"                    if donation <= BigMoney::ONE_CENT
        errors << "Donation: cannot donate more than the deposit amount." if deposit < donation
      end

      if params['pledge']
        pledge = parse_money(params['pledge']['amount']) {|e| errors << "Pledge: #{e}"}
        errors << "Pledge: must be atleast 0.01 USD"                    if pledge <= BigMoney::ONE_CENT
        errors << "Pledge: cannot pledge more than the deposit amount." if deposit < pledge
      end

      errors
    end

    def self.parse_money string
      if money = BigMoney.parse(string)
        money.exchange(:usd)
      else
        yield "unable to parse '#{string}' as money."
        BigMoney::ZERO
      end
    end
  end # Profile
end # Fundry
