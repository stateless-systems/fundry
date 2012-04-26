module Fundry
  class PaymentTrigger
    include DataMapper::Resource
    property :id,   Serial
    property :data, Json
    property :what, String
    property :completed, Boolean, required: true, default: false

    belongs_to :payment
    timestamps :at

    def process!
      case what
        when 'feature'
          feature = data['feature']['id'] ? Feature.get(data['feature']['id']) : Feature.create(data['feature'])
          amount  = BigMoney.parse!(data['pledge']['amount']).exchange(:usd)
          payment.user.pledge feature, amount, data['client_ip']
        when 'donation'
          project = Fundry::Project.get(data['donation']['project_id'])
          # users donating without signup.
          amount = if payment.user.username == User::Anonymous::USERNAME
            payment.balance
          else
            BigMoney.parse!(data['donation']['amount']).exchange(:usd)
          end
          anon    = !!data['donation']['anonymous']
          message = data['donation']['message']
          payment.user.donate project, amount, anon, (message && !message.empty? ? message : nil), data['client_ip']
      end
      update(completed: true)
    end

    def project
      case what
        when 'feature'
          Fundry::Project.get(data['feature']['project_id'])
        when 'donation'
          Fundry::Project.get(data['donation']['project_id'])
        else
          nil
      end
    end
  end
end
